# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Profile for the Hangar reprovision-runner on an on-network (MDC1) host.
#
# Follows ronin's normal secret convention: non-secret config lives in this
# role's data, the sensitive fields are dropped on the host in
# /var/root/vault.yaml (which run-puppet.sh copies to data/secrets/vault.yaml,
# the top hiera layer). Both are written flat under a single `reprovision_runner`
# key and combined with a DEEP merge, so config (role data) + secrets (vault.yaml)
# come together without one shadowing the other.
#
# Inert unless reprovision_runner.enabled is true, so it is safe to include
# broadly and enable per-host via role data.
class roles_profiles::profiles::reprovision_runner {
  $rr = lookup('reprovision_runner', Hash[String, Data], 'deep', {})

  if $rr['enabled'] == true {
    $cert_mode = pick_default($rr['cert_mode'], 'vault')

    # Worker/admin creds the `reprovision` CLI needs, from vault.yaml. Wrapped
    # Sensitive so they never surface in logs/reports.
    $secrets = {
      'REPROVISION_TC_CLIENT_ID'       => Sensitive(pick_default($rr['tc_client_id'], '')),
      'REPROVISION_TC_ACCESS_TOKEN'    => Sensitive(pick_default($rr['tc_access_token'], '')),
      'REPROVISION_SIMPLEMDM_API_KEY'  => Sensitive(pick_default($rr['simplemdm_api_key'], '')),
      'REPROVISION_SSH_ADMIN_PASSWORD' => Sensitive(pick_default($rr['ssh_admin_password'], '')),
      'REPROVISION_SSH_ADMIN_KEY'      => Sensitive(pick_default($rr['ssh_admin_key'], '')),
    }

    # cert_mode 'vault' also carries the mTLS client cert + key in vault.yaml.
    $client_cert = $cert_mode ? {
      'vault' => Sensitive(pick_default($rr['client_cert'], '')),
      default => undef,
    }
    $client_key = $cert_mode ? {
      'vault' => Sensitive(pick_default($rr['client_key'], '')),
      default => undef,
    }

    class { 'reprovision_runner':
      enabled        => true,
      cert_mode      => $cert_mode,
      hangar_api_url => pick_default($rr['hangar_api_url'], 'https://hangar.relops.mozilla.com/api'),
      runner_id      => pick_default($rr['runner_id'], $facts['networking']['hostname']),
      repo_url       => pick_default($rr['repo_url'], 'https://github.com/mozilla-platform-ops/relops-bootstrap.git'),
      repo_revision  => pick_default($rr['repo_revision'], 'main'),
      step_ca_url    => pick_default($rr['step_ca_url'], 'https://step-ca.relops.mozilla'),
      step_ca_ip     => pick_default($rr['step_ca_ip'], undef),
      client_cert    => $client_cert,
      client_key     => $client_key,
      secrets        => $secrets,
    }
  }
}
