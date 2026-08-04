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
# @param tart_health_enabled
#   Run hangar-tart-health-agent, which sweeps the tart VM hosts and pushes per-slot
#   health to Hangar. Requires tart_health_hosts.
# @param tart_health_hosts
#   Tart hosts to sweep, one FQDN per entry. Puppet writes the agent's hosts file, so a
#   host missing here is never checked.
# @param tart_health_interval
#   Seconds between sweeps. Must stay under Hangar's 30 minute staleness window or every
#   row ages to `unknown` between sweeps.
# @param tart_health_guests
#   Also probe inside each VM (disk headroom, clock skew, worker identity). Needs an
#   `expect` password login per VM and is much slower, hence opt-in — but these are the
#   checks that catch a crash-looping guest under a healthy host.
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
  Optional[String[1]]              $step_ca_ip     = undef,
  String[1]                        $step_version   = '0.28.2',
  Hash[Pattern[/^REPROVISION_[A-Z0-9_]+$/], Sensitive[String]] $secrets = {},
  Boolean                          $tart_health_enabled  = false,
  Array[Stdlib::Fqdn]              $tart_health_hosts    = [],
  Integer[60]                      $tart_health_interval = 600,
  Boolean                          $tart_health_guests   = false,
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

    # Companion: the hangar-screen-agent (on-demand VNC frames for the live view). Same
    # venv, same env file (HANGAR_API_URL + mTLS cert + admin creds), second LaunchDaemon.
    $screen_bin          = "${venv_dir}/bin/hangar-screen-agent"
    $screen_wrapper      = '/usr/local/bin/hangar-screen-agent.sh'
    $screen_plist_label  = 'com.mozilla.hangar-screen-agent'
    $screen_plist_path   = "/Library/LaunchDaemons/${screen_plist_label}.plist"

    # Companion: hangar-tart-health-agent (per-slot health of the tart VM hosts, pushed
    # to Hangar's /api/tart-health). Third daemon on the same venv/env file/cert.
    $tart_bin            = "${venv_dir}/bin/hangar-tart-health-agent"
    $tart_wrapper        = '/usr/local/bin/hangar-tart-health-agent.sh'
    $tart_plist_label    = 'com.mozilla.hangar-tart-health-agent'
    $tart_plist_path     = "/Library/LaunchDaemons/${tart_plist_label}.plist"
    $tart_hosts_file     = "${conf_dir}/tart-hosts.txt"

    # Every console script pyproject declares. The pip install is guarded on ALL of
    # them (see below), not just the newest one.
    $console_bins        = [$runner_bin, $screen_bin, $tart_bin]

    # Every daemon that runs code out of the editable install. A repo advance changes
    # the code these processes are executing, and a long-lived Python process does not
    # reload source, so each one must be restarted when the working copy moves. Used by
    # both Vcsrepo and Exec[reprovision_runner_pip_install] below.
    #
    # tart_reload only exists when $tart_health_enabled, so it can't be referenced
    # unconditionally -- Puppet would fail on a dangling resource reference.
    $daemon_reloads = $tart_health_enabled ? {
      true    => [
        Exec['reprovision_runner_reload'],
        Exec['reprovision_runner_screen_reload'],
        Exec['reprovision_runner_tart_reload'],
      ],
      default => [
        Exec['reprovision_runner_reload'],
        Exec['reprovision_runner_screen_reload'],
      ],
    }

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

    # vcsrepo runs `git config --system --add safe.directory` for the root-owned
    # clone (git's dubious-ownership guard). That writes /usr/local/etc/gitconfig,
    # whose parent dir doesn't exist by default on macOS — without it the clone
    # fails with "could not lock config file ...: No such file or directory".
    exec { 'reprovision_runner_git_systemdir':
      command => 'mkdir -p /usr/local/etc',
      path    => ['/bin', '/usr/bin'],
      creates => '/usr/local/etc',
    }

    vcsrepo { $repo_dir:
      ensure   => latest,
      provider => git,
      source   => $repo_url,
      revision => $repo_revision,
      owner    => 'root',
      group    => 'wheel',
      require  => [File[$install_dir], Exec['reprovision_runner_git_systemdir']],
      # Notify the reloads as well as the install. The install is guarded on the console
      # bins existing, so on any host with a working venv a code-only bump SKIPS it --
      # and with it, the reload notifications it would have sent. That left every daemon
      # running whatever code it started with, indefinitely: relops-bootstrap#60 (the
      # tart agent's stale ssh identity path) landed on main, vcsrepo pulled it onto
      # m4-81, and the agent kept executing the old module because nothing restarted it.
      # vcsrepo only notifies when it actually moves the working copy, so this restarts
      # daemons when commits land, not on every apply.
      notify   => [Exec['reprovision_runner_pip_install']] + $daemon_reloads,
    }

    exec { 'reprovision_runner_venv':
      command => "${python_bin} -m venv ${venv_dir}",
      path    => ['/usr/bin', '/bin'],
      creates => "${venv_dir}/bin/python",
      require => [Class['packages::python3'], File[$install_dir]],
    }

    # Editable install so a repo bump (vcsrepo latest) takes effect without a
    # rebuild. Re-runs when the venv is (re)created or the repo advances.
    # PIP_CONFIG_FILE=/dev/null ignores the fleet-wide /Library/Application Support/pip/pip.conf
    # (no-index + internal mirror), which only carries the CI worker's deps — the orchestrator's
    # deps (httpx, typer, taskcluster, …) live on public PyPI, which MDC1 can reach.
    # Guarded (not refreshonly): installs whenever ANY expected console script is
    # absent, so a partial/failed prior run self-heals on the next apply. The
    # editable install source-links the repo, so vcsrepo's `latest` pulls pick up
    # code changes without a reinstall — only a missing bin needs this to re-run.
    #
    # The guard tests EVERY script in $console_bins, because a `creates` on one bin
    # silently skips the install for all the others. That is not hypothetical: the
    # guard was `creates => $screen_bin`, and since hangar-screen-agent had existed
    # since July, adding hangar-tart-health-agent to pyproject never materialized it on
    # any host with an existing venv — vcsrepo pulled, this exec was notified, and the
    # guard short-circuited it. An editable install picks up *code* changes without
    # reinstalling, but a new [project.scripts] entry only appears on reinstall.
    $bins_present = $console_bins.map |$b| { "-x '${b}'" }.join(' -a ')
    exec { 'reprovision_runner_pip_install':
      command     => "${venv_dir}/bin/pip install --upgrade pip && ${venv_dir}/bin/pip install -e ${orch_dir}",
      path        => ['/usr/bin', '/bin'],
      environment => ['PIP_CONFIG_FILE=/dev/null'],
      unless      => "/bin/test ${bins_present}",
      timeout     => 900,
      require     => [Exec['reprovision_runner_venv'], Vcsrepo[$repo_dir]],
      # $daemon_reloads, not a hand-listed pair: this previously named the runner and
      # screen reloads only, so a run that DID reinstall (fresh venv, or a newly added
      # console script) still left the tart agent on its old process.
      notify      => $daemon_reloads,
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
        label    => $plist_label,
        wrapper  => $wrapper,
        log_dir  => $log_dir,
        log_name => 'runner',
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
      # Ordered after the install so that when a repo bump triggers both, the daemon
      # restarts onto the reinstalled code rather than racing it.
      require     => [File[$plist_path], Exec['reprovision_runner_pip_install']],
    }

    # ---- companion: hangar-screen-agent (VNC frames for the live view) ----
    # Reuses the runner's env file + the same wrapper/plist templates, pointed at the
    # screen-agent bin.
    file { $screen_wrapper:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0755',
      content => epp("${module_name}/reprovision-runner.sh.epp", {
        env_file   => $env_file,
        runner_bin => $screen_bin,
      }),
      require => Exec['reprovision_runner_pip_install'],
      notify  => Exec['reprovision_runner_screen_reload'],
    }

    file { $screen_plist_path:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      content => epp("${module_name}/com.mozilla.reprovision-runner.plist.epp", {
        label    => $screen_plist_label,
        wrapper  => $screen_wrapper,
        log_dir  => $log_dir,
        log_name => 'screen-agent',
      }),
      require => [File[$screen_wrapper], File[$env_file]],
      notify  => Exec['reprovision_runner_screen_reload'],
    }

    exec { 'reprovision_runner_screen_reload':
      command     => "/bin/bash -c 'launchctl bootout system ${screen_plist_path} 2>/dev/null || true; launchctl bootstrap system ${screen_plist_path}'",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      require     => [File[$screen_plist_path], Exec['reprovision_runner_pip_install']],
    }

    # ---- companion: hangar-tart-health-agent (per-slot tart VM health) ----
    # Third daemon on the same venv, env file and mTLS cert. Unlike the other two it
    # takes arguments, so the shared wrapper template renders an argv.
    #
    # Opt-in per host: only the runner host should sweep the tart fleet, and a daemon
    # with no hosts would push an empty payload that ages every row to `unknown`.
    if $tart_health_enabled {
      if empty($tart_health_hosts) {
        fail('reprovision_runner: tart_health_enabled requires a non-empty tart_health_hosts')
      }

      # Guest probes need an `expect` password login per VM and are much slower than the
      # host-level sweep, so they are opt-in separately.
      if $tart_health_guests {
        $guest_args = []
      } else {
        $guest_args = ['--no-guests']
      }
      $tart_args = [
        '--hosts-file', $tart_hosts_file,
        '--loop',
        '--interval', String($tart_health_interval),
      ] + $guest_args

      # Puppet owns the host list: hand-maintaining it means the daemon silently keeps
      # sweeping a stale fleet as hosts are added or converted. The agent ignores blank
      # lines and # comments.
      $tart_hosts_lines = ['# Managed by Puppet (reprovision_runner). Do not edit.'] + $tart_health_hosts
      $tart_hosts_content = join($tart_hosts_lines, "\n")

      file { $tart_hosts_file:
        ensure  => file,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0600',
        content => "${tart_hosts_content}\n",
        require => File[$conf_dir],
        notify  => Exec['reprovision_runner_tart_reload'],
      }

      file { $tart_wrapper:
        ensure  => file,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0755',
        content => epp("${module_name}/reprovision-runner.sh.epp", {
          env_file   => $env_file,
          runner_bin => $tart_bin,
          args       => $tart_args,
        }),
        require => Exec['reprovision_runner_pip_install'],
        notify  => Exec['reprovision_runner_tart_reload'],
      }

      file { $tart_plist_path:
        ensure  => file,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0644',
        content => epp("${module_name}/com.mozilla.reprovision-runner.plist.epp", {
          label    => $tart_plist_label,
          wrapper  => $tart_wrapper,
          log_dir  => $log_dir,
          log_name => 'tart-health-agent',
        }),
        require => [File[$tart_wrapper], File[$env_file], File[$tart_hosts_file]],
        notify  => Exec['reprovision_runner_tart_reload'],
      }

      exec { 'reprovision_runner_tart_reload':
        command     => "/bin/bash -c 'launchctl bootout system ${tart_plist_path} 2>/dev/null || true; launchctl bootstrap system ${tart_plist_path}'",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        require     => [File[$tart_plist_path], Exec['reprovision_runner_pip_install']],
      }
    }
  }
}
