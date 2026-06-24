# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::worker {
  case $facts['os']['name'] {
    'Darwin': {
      $generic_worker_engine = lookup('worker.generic_worker_engine')
      $task_user_password = $generic_worker_engine ? {
        'multiuser-static' => lookup('cltbld_user.unhashedpassword'),
        default            => undef,
      }

      # Taskcluster worker version precedence -- moving control out of vault.
      # Prefer a role-owned top-level `taskcluster_version` (managed here in
      # ronin role data) so a version bump is just a puppet change that workers
      # pick up on their next run. Fall back to the legacy vault-provided
      # `worker.taskcluster_version` for roles not yet migrated. The fallback is
      # lazy (only evaluated when the role key is unset) so it won't error once
      # vault's value is eventually retired.
      $role_taskcluster_version = lookup('taskcluster_version', String, 'first', undef)
      $taskcluster_version = $role_taskcluster_version ? {
        undef   => lookup('worker.taskcluster_version'),
        default => $role_taskcluster_version,
      }

      class { 'worker_runner':
        taskcluster_version   => $taskcluster_version,
        provider_type         => lookup('worker.provider_type'),
        root_url              => 'https://firefox-ci-tc.services.mozilla.com',
        client_id             => lookup('worker.client_id'),
        access_token          => lookup('worker.access_token'),
        worker_pool_id        => lookup('worker.worker_pool_id'),
        worker_group          => lookup('worker.worker_group'),
        worker_id             => lookup('worker.worker_id'),
        generic_worker_engine => $generic_worker_engine,
        idle_timeout_secs     => lookup('worker.idle_timeout_secs'),
        task_user_password    => $task_user_password,
      }
      # TODO: don't assume these are need with all workers. break out into another profile?
      include mercurial::system_hgrc
      include mercurial::ext::robustcheckout
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
