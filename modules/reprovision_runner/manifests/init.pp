# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Installs the Hangar reprovision-runner on an on-network (MDC1) host.
#
# Hangar (Cloud Run) cannot SSH into MDC1, so it only *queues* reprovision jobs.
# This runner lives on the VPN, polls Hangar over mTLS (outbound only, no inbound
# to MDC1), claims a job, runs the `reprovision` CLI, and streams progress back.
# It is the only component that holds worker SSH/admin creds; Hangar holds none.
# See relops-bootstrap: orchestrator/orchestrator/runner.py and
# hangar/docs/reprovision-mdc1-runner-design.md.
#
# This is a component module: single-OS (macOS), no profile calls, no hiera
# lookups. All configuration (including secret values) is passed by the
# roles_profiles::profiles::reprovision_runner profile.
#
# @param enabled
#   Master switch. When false the class is inert (nothing is managed).
# @param hangar_api_url
#   Base API URL Hangar exposes, e.g. https://hangar.relops.mozilla.com/api .
# @param runner_id
#   Label this runner reports to Hangar (defaults to the host's short name).
# @param repo_url
#   Git source of the relops-bootstrap repo that ships the orchestrator.
# @param repo_revision
#   Git ref (branch/tag/sha) to deploy.
# @param install_dir
#   Where the repo clone + venv live.
# @param python_version
#   python.org framework version to install (via packages::python3).
# @param poll_seconds
#   Claim poll interval when the queue is empty.
# @param cert_mode
#   How the mTLS client cert is provisioned:
#     'step_renew' (recommended) - Puppet installs the `step` CLI and a renew
#        LaunchDaemon that keeps a short-lived step-ca cert fresh; the private
#        key is generated on-host and never stored in vault/git. The one-time
#        initial enrollment is an operator bootstrap step (see README).
#     'vault' - cert + key content are delivered through vault.yaml and written
#        0600. Simple, ronin-native, but a long-lived key at rest + manual
#        rotation. Fallback only.
# @param client_cert
#   PEM client cert (leaf + intermediates). Required for cert_mode 'vault';
#   for 'step_renew' this path is populated by the initial enrollment + renew.
# @param client_key
#   PEM private key. Only consumed for cert_mode 'vault'.
# @param step_ca_url
#   step-ca base URL (cert_mode 'step_renew').
# @param step_version
#   smallstep `step` CLI version to install (cert_mode 'step_renew').
# @param secrets
#   REPROVISION_* creds the `reprovision` CLI needs, keyed by env var name, e.g.
#   { 'REPROVISION_TC_CLIENT_ID' => Sensitive('...'), ... }. Sourced from vault
#   by the profile and written to a 0600 env file the daemon sources.
class reprovision_runner (
  Boolean                          $enabled        = false,
  String[1]                        $hangar_api_url = 'https://hangar.relops.mozilla.com/api',
  String[1]                        $runner_id      = $facts['networking']['hostname'],
  String[1]                        $repo_url       = 'https://github.com/mozilla-platform-ops/relops-bootstrap.git',
  String[1]                        $repo_revision  = 'main',
  String[1]                        $install_dir    = '/opt/reprovision-runner',
  Pattern[/^\d+\.\d+\.\d+$/]       $python_version = '3.11.0',
  Integer[1]                       $poll_seconds   = 10,
  Enum['step_renew', 'vault']      $cert_mode      = 'step_renew',
  Optional[Sensitive[String[1]]]   $client_cert    = undef,
  Optional[Sensitive[String[1]]]   $client_key     = undef,
  String[1]                        $step_ca_url    = 'https://step-ca.relops.mozilla',
  String[1]                        $step_version   = '0.28.2',
  Hash[Pattern[/^REPROVISION_[A-Z0-9_]+$/], Sensitive[String]] $secrets = {},
) {
  if $enabled {
    $short_python  = split(String($python_version), '[.]')[0, 2].join('.')
    $python_bin    = "/Library/Frameworks/Python.framework/Versions/${short_python}/bin/python3"
    $repo_dir      = "${install_dir}/repo"
    $orch_dir      = "${repo_dir}/orchestrator"
    $venv_dir      = "${install_dir}/.venv"
    $runner_bin    = "${venv_dir}/bin/reprovision-runner"

    $conf_dir      = '/var/root/reprovision-runner'
    $cert_path     = "${conf_dir}/client.crt"
    $key_path      = "${conf_dir}/client.key"
    $env_file      = "${conf_dir}/runner.env"
    $wrapper       = '/usr/local/bin/reprovision-runner.sh'
    $log_dir       = '/var/log/reprovision-runner'
    $plist_label   = 'com.mozilla.reprovision-runner'
    $plist_path    = "/Library/LaunchDaemons/${plist_label}.plist"

    # ---- python 3.11 (framework build, same source as scriptworker_prereqs) ----
    class { 'packages::python3':
      version => $python_version,
    }

    # ---- code: clone relops-bootstrap + build a venv + editable-install ----
    file { $install_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    vcsrepo { $repo_dir:
      ensure   => latest,
      provider => git,
      source   => $repo_url,
      revision => $repo_revision,
      owner    => 'root',
      group    => 'wheel',
      require  => File[$install_dir],
      notify   => Exec['reprovision_runner_pip_install'],
    }

    exec { 'reprovision_runner_venv':
      command => "${python_bin} -m venv ${venv_dir}",
      path    => ['/usr/bin', '/bin'],
      creates => "${venv_dir}/bin/python",
      require => [Class['packages::python3'], File[$install_dir]],
    }

    # Editable install so a repo bump (vcsrepo latest) takes effect without a
    # rebuild. Re-runs when the venv is (re)created or the repo advances.
    exec { 'reprovision_runner_pip_install':
      command     => "${venv_dir}/bin/pip install --upgrade pip && ${venv_dir}/bin/pip install -e ${orch_dir}",
      path        => ['/usr/bin', '/bin'],
      refreshonly => true,
      timeout     => 900,
      subscribe   => Exec['reprovision_runner_venv'],
      require     => [Exec['reprovision_runner_venv'], Vcsrepo[$repo_dir]],
      notify      => Exec['reprovision_runner_reload'],
    }

    # ---- config dir + cert/key + env file (all root-only) ----
    file { $conf_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0700',
    }

    file { $log_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    # mTLS cert acquisition.
    case $cert_mode {
      'vault': {
        # Long-lived cert + key delivered through vault.yaml. Written 0600; the
        # private key is at rest here, so rotate it before expiry (see README).
        if $client_cert =~ Undef or $client_key =~ Undef {
          fail('reprovision_runner: cert_mode "vault" requires client_cert and client_key')
        }
        file { $cert_path:
          ensure    => file,
          owner     => 'root',
          group     => 'wheel',
          mode      => '0600',
          show_diff => false,
          content   => $client_cert,
          require   => File[$conf_dir],
          notify    => Exec['reprovision_runner_reload'],
        }
        file { $key_path:
          ensure    => file,
          owner     => 'root',
          group     => 'wheel',
          mode      => '0600',
          show_diff => false,
          content   => $client_key,
          require   => File[$conf_dir],
          notify    => Exec['reprovision_runner_reload'],
        }
      }
      'step_renew': {
        # Recommended: on-host key, short-lived cert, auto-renewed. Puppet manages
        # the `step` CLI + a renew daemon; the *initial* enrollment is a one-time
        # operator bootstrap (README) because it needs a single-use credential.
        # The private key never lands in vault or git.
        contain reprovision_runner::step_renew
      }
      default: {
        fail("reprovision_runner: unsupported cert_mode '${cert_mode}'")
      }
    }

    # Secrets -> 0600 env file the daemon sources. Values are single-quote-escaped
    # so multi-line PEM keys and arbitrary chars survive `source`. The whole
    # content is Sensitive; show_diff is off so secrets never hit the puppet log.
    $secret_exports = $secrets.map |$k, $v| {
      $escaped = regsubst($v.unwrap, "'", "'\\''", 'G')
      "export ${k}='${escaped}'"
    }.join("\n")

    $env_content = @("ENVFILE"/L)
      # Managed by Puppet (reprovision_runner). Do not edit.
      export HANGAR_API_URL='${hangar_api_url}'
      export RUNNER_ID='${runner_id}'
      export RUNNER_CLIENT_CERT='${cert_path}'
      export RUNNER_CLIENT_KEY='${key_path}'
      export RUNNER_POLL_SECONDS='${poll_seconds}'
      ${secret_exports}
      | ENVFILE

    file { $env_file:
      ensure    => file,
      owner     => 'root',
      group     => 'wheel',
      mode      => '0600',
      show_diff => false,
      content   => Sensitive($env_content),
      require   => File[$conf_dir],
      notify    => Exec['reprovision_runner_reload'],
    }

    # ---- wrapper: source the env file, exec the venv runner ----
    file { $wrapper:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0755',
      content => epp("${module_name}/reprovision-runner.sh.epp", {
        env_file   => $env_file,
        runner_bin => $runner_bin,
      }),
      notify  => Exec['reprovision_runner_reload'],
    }

    # ---- LaunchDaemon: RunAtLoad + KeepAlive, headless, survives reboot ----
    file { $plist_path:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      content => epp("${module_name}/com.mozilla.reprovision-runner.plist.epp", {
        label   => $plist_label,
        wrapper => $wrapper,
        log_dir => $log_dir,
      }),
      require => [File[$wrapper], File[$env_file]],
      notify  => Exec['reprovision_runner_reload'],
    }

    # system domain: loads headlessly, no console session required. bootout then
    # bootstrap so an edited plist is actually re-read (kickstart alone would
    # not pick up plist changes). Wrapped in bash -c for the shell operators.
    exec { 'reprovision_runner_reload':
      command     => "/bin/bash -c 'launchctl bootout system ${plist_path} 2>/dev/null || true; launchctl bootstrap system ${plist_path}'",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      require     => File[$plist_path],
    }
  }
}
