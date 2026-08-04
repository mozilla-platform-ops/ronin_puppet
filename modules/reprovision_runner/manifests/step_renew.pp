# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# cert_mode 'step_renew' helper for reprovision_runner (the recommended,
# review-friendly cert path).
#
# Installs the smallstep `step` CLI and a renew LaunchDaemon that keeps the
# runner's short-lived mTLS client cert fresh. Properties a security review
# looks for:
#   - the private key is generated ON-HOST at enrollment and never leaves it
#     (nothing in vault, nothing in git),
#   - certs are short-lived and auto-rotated (small blast radius),
#   - renewal is authenticated by the *current* cert (mTLS), so after bootstrap
#     there is no stored long-lived credential,
#   - the cert is centrally revocable at step-ca.
#
# The one-time INITIAL enrollment needs a single-use credential, so it is an
# operator bootstrap step (see README) UNLESS a single-use $enrollment_token is
# supplied via vault, in which case Puppet enrolls once (when the cert is
# absent). A short-lived token in vault is far weaker material than a long-lived
# private key would be.
#
# Params are bound from hiera (e.g. vault.yaml):
#   reprovision_runner::step_renew::ca_fingerprint
#   reprovision_runner::step_renew::enrollment_token
class reprovision_runner::step_renew (
  Optional[String[1]]            $ca_fingerprint   = undef,
  Optional[Sensitive[String[1]]] $enrollment_token = undef,
) {
  assert_private('reprovision_runner::step_renew is a private helper of reprovision_runner')

  # Pull the shared paths/config from the enclosing class.
  $conf_dir    = $reprovision_runner::conf_dir
  $cert_path   = $reprovision_runner::cert_path
  $key_path    = $reprovision_runner::key_path
  $step_ca_url = $reprovision_runner::step_ca_url
  $step_ca_ip  = $reprovision_runner::step_ca_ip
  $step_ver    = $reprovision_runner::step_version
  $runner_id   = $reprovision_runner::runner_id
  $plist_label = $reprovision_runner::plist_label

  # step-ca lives in GCP and is only reachable from MDC1 by IP; its hostname isn't in MDC1 DNS.
  # When $step_ca_ip is set, pin it in /etc/hosts so `step ca bootstrap`/`renew` resolve the
  # name (the cert's SAN is the hostname, so TLS validates against the name, not the IP).
  $ca_host = regsubst(regsubst($step_ca_url, '^https?://', ''), '[:/].*$', '')
  if $step_ca_ip {
    host { $ca_host:
      ensure => present,
      ip     => $step_ca_ip,
    }
    # Ensure the hosts entry is written before the bootstrap tries to resolve the name.
    # (Exec['step_ca_bootstrap'] only exists when $ca_fingerprint is set — guard the ordering.)
    if $ca_fingerprint {
      Host[$ca_host] -> Exec['step_ca_bootstrap']
    }
  }

  $step_bin    = '/usr/local/bin/step'
  $step_path   = "${conf_dir}/step" # STEPPATH: CA trust bundle + config
  $arch        = $facts['os']['architecture'] ? { 'arm64' => 'arm64', default => 'amd64' }
  $renew_label = 'com.mozilla.reprovision-runner-certrenew'
  $renew_plist = "/Library/LaunchDaemons/${renew_label}.plist"

  # ---- install the step CLI ----
  exec { 'install_step_cli':
    command => "/bin/bash -c 'set -e; tmp=\$(mktemp -d); cd \"\$tmp\"; \
                curl -fsSL -o step.tar.gz https://github.com/smallstep/cli/releases/download/v${step_ver}/step_darwin_${step_ver}_${arch}.tar.gz; \
                tar -xzf step.tar.gz; mkdir -p /usr/local/bin; \
                install -m 0755 step_${step_ver}/bin/step ${step_bin}; \
                cd /; rm -rf \"\$tmp\"'",
    path    => ['/usr/bin', '/bin'],
    creates => $step_bin,
    timeout => 300,
  }

  file { $step_path:
    ensure  => directory,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0700',
    require => File[$conf_dir],
  }

  # ---- bootstrap CA trust (idempotent; needs the CA root fingerprint) ----
  if $ca_fingerprint {
    exec { 'step_ca_bootstrap':
      command     => "${step_bin} ca bootstrap --ca-url ${step_ca_url} --fingerprint ${ca_fingerprint} --force",
      environment => ["STEPPATH=${step_path}"],
      path        => ['/usr/bin', '/bin', '/usr/local/bin'],
      creates     => "${step_path}/certs/root_ca.crt",
      require     => [Exec['install_step_cli'], File[$step_path]],
    }
    $enroll_require = [Exec['step_ca_bootstrap']]
  } else {
    $enroll_require = [Exec['install_step_cli']]
  }

  # ---- optional automated initial enrollment (one-time, when cert absent) ----
  # command is Sensitive so the single-use token never lands in the puppet log.
  if $enrollment_token =~ NotUndef {
    exec { 'step_initial_enroll':
      command     => Sensitive("${step_bin} ca certificate ${runner_id} ${cert_path} ${key_path} --token ${enrollment_token.unwrap} --force"),
      environment => ["STEPPATH=${step_path}"],
      path        => ['/usr/bin', '/bin', '/usr/local/bin'],
      creates     => $cert_path,
      require     => $enroll_require + [File[$conf_dir]],
      notify      => Exec['reprovision_runner_reload'],
    }
  }

  # ---- renew daemon: refresh at ~2/3 lifetime, kick the runner on renewal ----
  # `step ca renew --daemon` no-ops until a cert exists, so this is safe to load
  # before the initial enrollment; KeepAlive + ThrottleInterval back it off.
  file { $renew_plist:
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('reprovision_runner/com.mozilla.reprovision-runner-certrenew.plist.epp', {
      label     => $renew_label,
      step_bin  => $step_bin,
      step_path => $step_path,
      cert_path => $cert_path,
      key_path  => $key_path,
      exec_kick => "/bin/launchctl kickstart -k system/${plist_label}",
    }),
    require => Exec['install_step_cli'],
    notify  => Exec['reprovision_runner_certrenew_reload'],
  }

  exec { 'reprovision_runner_certrenew_reload':
    command     => "/bin/bash -c 'launchctl bootout system ${renew_plist} 2>/dev/null || true; launchctl bootstrap system ${renew_plist}'",
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    require     => File[$renew_plist],
  }
}
