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
            # TODO: don't assume these are need with all workers. break out into another profile?
            include mercurial::system_hgrc
            include mercurial::ext::robustcheckout

            class { 'telegraf':
                global_tags  => {
                    workerId          => lookup('worker.worker_id'),
                    workerGroup       => lookup('worker.worker_group'),
                    workerType        => split(lookup('worker.worker_pool_id'), '/')[1],
                    provisionerId     => split(lookup('worker.worker_pool_id'), '/')[0],
                },
                agent_params => {
                    interval          => '300s',
                    round_interval    => true,
                    collection_jitter => '0s',
                    flush_interval    => '120s',
                    flush_jitter      => '60s',
                    precision         => 's',
                },
                inputs       => {
                    # current default telegraf monitors: system, mem, swap, disk'/', puppetagent
                    temp     => {},
                    cpu      => {
                        interval         => '60s',
                        percpu           => true,
                        totalcpu         => true,
                        ## If true, collect raw CPU time metrics.
                        collect_cpu_time => false,
                        ## If true, compute and report the sum of all non-idle CPU states.
                        report_active    => false,
                    },
                    diskio   => {},
                    procstat => {
                        interval => '60s',
                        exe      => 'generic-worker-simple',
                    },
                },
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
