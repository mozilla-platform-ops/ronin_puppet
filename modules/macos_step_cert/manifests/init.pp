# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# A self-renewing, file-based step-ca client identity for a macOS host.
#
# Installs the smallstep `step` CLI plus a renew LaunchDaemon that keeps a
# short-lived mTLS client cert fresh. Security properties (the ones a review
# asks about):
#   - the private key is generated ON-HOST at enrollment and never leaves it
#     (nothing in vault, nothing in git),
#   - certs are short-lived and auto-rotated (small blast radius),
#   - renewal is authenticated by the *current* cert (mTLS), so after bootstrap
#     there is no stored long-lived credential,
#   - the cert is centrally revocable at step-ca.
#
# WHY THIS EXISTS SEPARATELY FROM THE MDM/SCEP CERT
# -------------------------------------------------
# relops-bootstrap enrolls hosts an SCEP cert via an MDM config profile. That
# cert lands in the System keychain with KeyIsExtractable=false and has NO
# renewal mechanism: Apple's com.apple.security.scep payload does not self-renew,
# and it only refreshes if the MDM re-installs the profile. It is also issued
# with step-ca's *default* 24h lifetime, because the SCEP provisioners are added
# without duration claims (relops-bootstrap scripts/bootstrap-step-ca.sh).
#
# That is fine for its designed purpose — the bootstrap flow uses it once, minutes
# after enrollment, to fetch vault.yaml. It is NOT suitable for anything that
# needs an identity at *runtime*, which is why the tart VM hosts (whose
# tart-run-vm.sh fetches the worker vault on every VM launch) get this instead.
# Because the SCEP private key is non-extractable, `step ca renew` cannot operate
# on it — a separate file-based identity is required, not a fix to the SCEP one.
#
# ENROLLMENT
# ----------
# Initial enrollment needs a single-use credential. Drop one at $token_file
# (mint it with relops-bootstrap scripts/mint-tart-enrollment-token.sh) and puppet
# enrolls when the cert is missing OR already expired, then REMOVES the file so it
# is genuinely single-use.
#
# THE CERT MUST CARRY A SPIFFE URI SAN, or the vault-broker will refuse it. The
# broker authorizes on the puppet role stamped into
# `spiffe://relops.mozilla/host/<CN>/role/<role>`. This class does NOT set it:
# with a token, the subject/SANs come from the token and the issuing
# provisioner's x509 template. relops-bootstrap's JWK_ROLES provisioners stamp it
# from the template (one provisioner per role), so nothing is needed here — but if
# you enroll against a provisioner WITHOUT that template, the cert will look
# perfectly valid and every broker fetch will still fail authorization. Verify
# after enrolling:
#
#   openssl x509 -in <cert_path> -noout -text | grep -A1 'Alternative Name'
#
# Use -text, NOT `-ext subjectAltName`: macOS ships LibreSSL, which does not
# support -ext and silently prints its help output instead, so the SAN looks
# absent when it is present (cost 20 minutes on m4-235, 2026-07-27).
#
# The token deliberately arrives as a file rather than through hiera. An earlier
# revision took it as a vault-delivered Sensitive value, which cannot work:
# /var/root/vault.yaml is 0 bytes on these hosts, so the vault hiera layer is
# empty and anything routed through it resolves to undef. A file is also better on
# its own merits — the token never enters puppet's catalog or logs — and it matches
# the delivery path that already exists, since the bootstrap PKG / reprovision
# orchestrator already drops /var/root/vault.yaml over the same channel.
#
# When no token is present and no valid cert exists, this class logs and moves on
# rather than failing the whole puppet run: on a host that has not been enrolled
# yet that is an expected state, not an error. The absence is visible in
# `step ca renew`'s log and in the missing cert, which is what the caller checks.
#
# Operational note: `step ca renew` requires a cert that is still VALID, so a host
# powered off longer than the cert lifetime cannot renew and must re-enroll — which
# is why enrollment triggers on expiry, not just absence. The CA side deliberately
# does NOT set allowRenewalAfterExpiry (relops-bootstrap #52): allowing renewal of
# an expired cert would let a leaked cert be renewed indefinitely, since renewal is
# authenticated by the cert itself. Instead the provisioners issue 720h certs, so
# the renew window covers most of a month of downtime, and anything past that
# re-enrolls.
#
# This is a component module: single-OS (macOS), no profile calls, no hiera
# lookups. All configuration is passed in by the calling profile.
#
# TODO: reprovision_runner::step_renew predates this module and duplicates it.
# It is left untouched here on purpose — it is a live, security-reviewed cert
# path and refactoring it in the same change that introduces a second consumer
# would double the risk surface. Migrate it to this module as a follow-up.
#
# @param cert_path
#   Where the PEM leaf cert is written/renewed.
# @param key_path
#   Where the PEM private key is generated. Never leaves the host.
# @param subject
#   Cert subject/CN to enroll as (typically the host's short name).
# @param enabled
#   Master switch. When false the class is inert (nothing is managed).
# @param step_ca_url
#   step-ca base URL.
# @param step_ca_ip
#   Optional IP to pin $step_ca_url's hostname to in /etc/hosts. step-ca lives in
#   GCP and is reachable from MDC1 by IP only; its name isn't in MDC1 DNS. TLS
#   still validates against the name (that's the cert's SAN), hence the pin
#   rather than using the IP in the URL.
# @param step_version
#   smallstep `step` CLI version to install.
# @param ca_fingerprint
#   step-ca root fingerprint, for `step ca bootstrap` trust establishment.
# @param token_file
#   Path to a file holding a single-use JWK enrollment token. When the file is
#   present and there is no valid cert, Puppet enrolls and then removes the file.
#   Deliberately a file, not a hiera/vault value — see ENROLLMENT above.
# @param conf_dir
#   Base dir for STEPPATH (CA trust bundle + step config). Mode 0700.
# @param label
#   launchd label for the renew daemon.
# @param exec_kick
#   Optional command `step ca renew --exec` runs after a successful renewal (to
#   restart whatever consumes the cert). Omit when the consumer re-reads the
#   file on its own, as tart-run-vm.sh does.
# @param log_dir
#   Directory for the renew daemon's stdout/stderr.
class macos_step_cert (
  String[1]                      $cert_path,
  String[1]                      $key_path,
  String[1]                      $subject,
  Boolean                        $enabled          = false,
  String[1]                      $step_ca_url      = 'https://step-ca.relops.mozilla',
  Optional[String[1]]            $step_ca_ip       = undef,
  String[1]                      $step_version     = '0.28.2',
  Optional[String[1]]            $ca_fingerprint   = undef,
  String[1]                      $token_file       = '/var/root/step-enrollment-token',
  String[1]                      $conf_dir         = '/etc/step-cert',
  String[1]                      $label            = 'com.mozilla.step-certrenew',
  Optional[String[1]]            $exec_kick        = undef,
  String[1]                      $log_dir          = '/var/log/step-cert',
) {
  if $enabled {
    $step_bin    = '/usr/local/bin/step'
    $step_path   = "${conf_dir}/step"
    $arch        = $facts['os']['architecture'] ? { 'arm64' => 'arm64', default => 'amd64' }
    $renew_plist = "/Library/LaunchDaemons/${label}.plist"

    # ---- dirs ----
    file { [$conf_dir, $step_path]:
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0700',
    }

    file { $log_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0750',
    }

    # ---- pin the CA hostname when it isn't in local DNS ----
    $ca_host = regsubst(regsubst($step_ca_url, '^https?://', ''), '[:/].*$', '')
    if $step_ca_ip {
      host { $ca_host:
        ensure => present,
        ip     => $step_ca_ip,
      }
      if $ca_fingerprint {
        Host[$ca_host] -> Exec["${label}_ca_bootstrap"]
      }
    }

    # ---- install the step CLI ----
    exec { "${label}_install_step_cli":
      command => "/bin/bash -c 'set -e; tmp=\$(mktemp -d); cd \"\$tmp\"; \
                  curl -fsSL -o step.tar.gz https://github.com/smallstep/cli/releases/download/v${step_version}/step_darwin_${step_version}_${arch}.tar.gz; \
                  tar -xzf step.tar.gz; mkdir -p /usr/local/bin; \
                  install -m 0755 step_${step_version}/bin/step ${step_bin}; \
                  cd /; rm -rf \"\$tmp\"'",
      path    => ['/usr/bin', '/bin'],
      creates => $step_bin,
      timeout => 300,
    }

    # ---- bootstrap CA trust (idempotent) ----
    if $ca_fingerprint {
      exec { "${label}_ca_bootstrap":
        command     => "${step_bin} ca bootstrap --ca-url ${step_ca_url} --fingerprint ${ca_fingerprint} --force",
        environment => ["STEPPATH=${step_path}"],
        path        => ['/usr/bin', '/bin', '/usr/local/bin'],
        creates     => "${step_path}/certs/root_ca.crt",
        require     => [Exec["${label}_install_step_cli"], File[$step_path]],
      }
      $enroll_require = [Exec["${label}_ca_bootstrap"]]
    } else {
      $enroll_require = [Exec["${label}_install_step_cli"]]
    }

    # ---- one-time enrollment from a token file (also re-enrolls an EXPIRED cert) ----
    # Two guards, both evaluated at run time rather than catalog time:
    #   onlyif - a token file must actually be present. On a host that has not been
    #            handed one yet this simply does nothing, which is a normal state,
    #            not an error.
    #   unless - -checkend rather than `creates`, so a cert that expired while the
    #            host was off (past the renew daemon's window) is replaced instead
    #            of sitting dead. openssl also exits non-zero when the file is
    #            missing, so the one test covers absent AND expired.
    #
    # The token is read by the shell and never interpolated into the catalog, so it
    # cannot reach puppet reports or logs. It is deleted only after a SUCCESSFUL
    # enrollment (set -e before the rm), so a failed attempt is retried next run
    # rather than silently burning the token.
    exec { "${label}_initial_enroll":
      command     => "/bin/bash -c 'set -e; tok=\$(/bin/cat ${token_file}); ${step_bin} ca certificate ${subject} ${cert_path} ${key_path} --token \"\$tok\" --force; /bin/rm -f ${token_file}'",
      onlyif      => "/bin/test -s ${token_file}",
      unless      => "/usr/bin/openssl x509 -checkend 300 -noout -in ${cert_path}",
      environment => ["STEPPATH=${step_path}"],
      path        => ['/usr/bin', '/bin', '/usr/local/bin'],
      require     => $enroll_require + [File[$conf_dir]],
      notify      => Exec["${label}_reload"],
    }

    # ---- renew daemon ----
    # `step ca renew --daemon` no-ops until a cert exists, so this is safe to
    # load before enrollment; KeepAlive + ThrottleInterval back it off.
    file { $renew_plist:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      content => epp('macos_step_cert/certrenew.plist.epp', {
          label     => $label,
          step_bin  => $step_bin,
          step_path => $step_path,
          cert_path => $cert_path,
          key_path  => $key_path,
          exec_kick => $exec_kick,
          log_dir   => $log_dir,
      }),
      require => [Exec["${label}_install_step_cli"], File[$log_dir]],
      notify  => Exec["${label}_reload"],
    }

    exec { "${label}_reload":
      command     => "/bin/bash -c 'launchctl bootout system ${renew_plist} 2>/dev/null || true; launchctl bootstrap system ${renew_plist}'",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      require     => File[$renew_plist],
    }
  }
}
