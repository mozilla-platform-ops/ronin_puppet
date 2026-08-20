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
      $role_taskcluster_version = lookup('taskcluster_version', Optional[String], 'first', undef)
      $taskcluster_version = $role_taskcluster_version ? {
        undef   => lookup('worker.taskcluster_version'),
        default => $role_taskcluster_version,
      }

      # Developer-ID-signed worker binaries, opt-in per role as
      # installed-binary-name => expected sha256. Mozilla signs only a subset of
      # the release assets, so this is a map rather than a boolean; an empty map
      # (the default) keeps every binary on the ad-hoc GitHub release asset.
      $signed_binaries = lookup('taskcluster_signed_binaries', Hash[String, String], 'first', {})

      # Free-space floor for the between-tasks OS cache reclaim, opt-in per role.
      # Unset means the feature is absent entirely rather than merely inert, so a
      # role that does not ask for it gains no script, no sudoers rule and an
      # unchanged worker-runner.sh. Only the tart VM guests need it: they sit at
      # ~20 GiB headroom against generic-worker's 20 GiB requirement, where
      # sampled bare-metal testers have 89-154 GiB free.
      #
      # Deliberately a TOP-LEVEL role key, not `worker.reclaim_free_space_gb`.
      # secrets/vault.yaml is the highest-priority hierarchy level and it owns a
      # `worker:` hash; for a dotted key hiera resolves the root key from the first
      # source that has it and then traverses, so vault's hash wins outright and any
      # sub-key that exists only in role data is invisible. #1329 shipped with the
      # lookup under `worker.` and silently compiled the whole feature out. Same
      # reason `taskcluster_version` above is read from the top level.
      $reclaim_free_space_gb = lookup('reclaim_free_space_gb', Optional[Integer], 'first', undef)

      class { 'worker_runner':
        taskcluster_version   => $taskcluster_version,
        signed_binaries       => $signed_binaries,
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
        reclaim_free_space_gb => $reclaim_free_space_gb,
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
