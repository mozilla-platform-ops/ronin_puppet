# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_talos_generic_worker {

    case $::operatingsystem {
        'Ubuntu': {
            contain linux_packages::py2
            contain linux_packages::py3

            contain linux_packages::python2_zstandard
            contain linux_packages::python3_zstandard

            contain linux_packages::zstd

            # g-w
            $worker_type  = 'gecko-t-linux-talos'
            $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

            $taskcluster_client_id    = lookup('generic_worker.gecko_t_linux_talos.taskcluster_client_id')
            $taskcluster_access_token = lookup('generic_worker.gecko_t_linux_talos.taskcluster_access_token')
            $livelog_secret           = lookup('generic_worker.gecko_t_linux_talos.livelog_secret')
            $quarantine_client_id     = lookup('generic_worker.gecko_t_linux_talos.quarantine_client_id')
            $quarantine_access_token  = lookup('generic_worker.gecko_t_linux_talos.quarantine_access_token')
            $bugzilla_api_key         = lookup('generic_worker.gecko_t_linux_talos.bugzilla_api_key')

            class { 'linux_generic_worker':
                taskcluster_client_id     => $taskcluster_client_id,
                taskcluster_access_token  => $taskcluster_access_token,
                livelog_secret            => $livelog_secret,
                worker_group              => $worker_group,
                worker_type               => $worker_type,
                quarantine_client_id      => $quarantine_client_id,
                quarantine_access_token   => $quarantine_access_token,
                bugzilla_api_key          => $bugzilla_api_key,
                generic_worker_version    => 'v16.6.1',
                # generic_worker_sha256     => '6e5c1543fb3c333ca783d0a5c4e557b2b5438aada4bc23dc02402682ae4e245e',
                taskcluster_proxy_version => 'v5.1.0',
                # taskcluster_proxy_sha256  => '3faf524b9c6b9611339510797bf1013d4274e9f03e7c4bd47e9ab5ec8813d3ae',
                quarantine_worker_version => 'v1.0.0',
                # quarantine_worker_sha256  => '60bb15fa912589fd8d94dbbff2e27c2718eadaf2533fc4bbefb887f469e22627',
                user                      => 'cltbld',
                user_homedir              => '/home/cltbld',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
