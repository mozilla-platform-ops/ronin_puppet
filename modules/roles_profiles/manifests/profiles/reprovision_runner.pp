# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Profile for the Hangar reprovision-runner on an on-network (MDC1) host.
# Does the hiera lookups (non-secret config from role data, creds from
# vault.yaml) and hands them to the reprovision_runner component module.
#
# Inert unless reprovision_runner.enabled is true in hiera, so it is safe to
# include broadly and enable per-host via role data.
class roles_profiles::profiles::reprovision_runner {
  $enabled = lookup('reprovision_runner.enabled', Boolean, 'first', false)

  if $enabled {
    $cert_mode = lookup('reprovision_runner.cert_mode', Enum['step_renew', 'vault'], 'first', 'step_renew')

    # Worker/admin creds the `reprovision` CLI needs, sourced from vault.yaml.
    # Wrapped Sensitive so they never surface in logs/reports.
    $secrets = {
      'REPROVISION_TC_CLIENT_ID'       => Sensitive(lookup('reprovision_runner.tc_client_id', String, 'first', '')),
      'REPROVISION_TC_ACCESS_TOKEN'    => Sensitive(lookup('reprovision_runner.tc_access_token', String, 'first', '')),
      'REPROVISION_SIMPLEMDM_API_KEY'  => Sensitive(lookup('reprovision_runner.simplemdm_api_key', String, 'first', '')),
      'REPROVISION_SSH_ADMIN_PASSWORD' => Sensitive(lookup('reprovision_runner.ssh_admin_password', String, 'first', '')),
      'REPROVISION_SSH_ADMIN_KEY'      => Sensitive(lookup('reprovision_runner.ssh_admin_key', String, 'first', '')),
    }

    # cert_mode 'vault' additionally delivers the cert + key through vault.yaml.
    # 'step_renew' (default) generates the key on-host and needs neither here.
    $client_cert = $cert_mode ? {
      'vault' => Sensitive(lookup('reprovision_runner.client_cert', String, 'first', '')),
      default => undef,
    }
    $client_key = $cert_mode ? {
      'vault' => Sensitive(lookup('reprovision_runner.client_key', String, 'first', '')),
      default => undef,
    }

    class { 'reprovision_runner':
      enabled        => true,
      cert_mode      => $cert_mode,
      hangar_api_url => lookup('reprovision_runner.hangar_api_url', String, 'first', 'https://hangar.relops.mozilla.com/api'),
      runner_id      => lookup('reprovision_runner.runner_id', String, 'first', $facts['networking']['hostname']),
      repo_url       => lookup('reprovision_runner.repo_url', String, 'first', 'https://github.com/mozilla-platform-ops/relops-bootstrap.git'),
      repo_revision  => lookup('reprovision_runner.repo_revision', String, 'first', 'main'),
      step_ca_url    => lookup('reprovision_runner.step_ca_url', String, 'first', 'https://step-ca.relops.mozilla'),
      client_cert    => $client_cert,
      client_key     => $client_key,
      secrets        => $secrets,
    }
  }
}
