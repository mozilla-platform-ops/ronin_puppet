# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::worker {

    case $::operatingsystem {
        'Darwin': {

            class { 'worker_runner':
                taskcluster_version   => lookup('worker.taskcluster_version'),
                provider_type         => lookup('worker.provider_type'),
                root_url              => 'https://firefox-ci-tc.services.mozilla.com',
                client_id             => lookup('worker.client_id'),
                access_token          => lookup('worker.access_token'),
                worker_pool_id        => lookup('worker.worker_pool_id'),
                worker_group          => lookup('worker.worker_group'),
                worker_id             => lookup('worker.worker_id'),
                generic_worker_engine => lookup('worker.generic_worker_engine'),
                idle_timeout_secs     => lookup('worker.idle_timeout_secs'),
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
