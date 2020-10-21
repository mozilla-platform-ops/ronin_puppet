# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_talos_generic_worker {

    # TODO: make these args to this module and use in call in gecko_t_linux_talos?
    $worker_type  = 'gecko-t-linux-talos-dw'
    $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

    case $::operatingsystem {
        'Ubuntu': {
            require roles_profiles::profiles::cltbld_user

            # TODO: move these lines to linux-base?
            require linux_packages::py2
            require linux_packages::py3
            require linux_packages::ffmpeg
            require linux_packages::imagemagick
            require linux_packages::psutil_py2
            require linux_packages::psutil_py3
            require linux_packages::python2_zstandard
            require linux_packages::python3_zstandard
            include linux_packages::tooltool
            require linux_packages::zstd

            require linux_talos

            class { 'puppet::atboot':
                telegraf_user     => lookup('telegraf.user'),
                telegraf_password => lookup('telegraf.password'),
                # Note the camelCase key names
                meta_data         => {
                    workerType    => $worker_type,
                    workerGroup   => $worker_group,
                    provisionerId => 'releng-hardware',
                    workerId      => $facts['networking']['hostname'],
                },
            }

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
                generic_worker_version    => 'v37.3.0',
                generic_worker_sha256     => 'be028023d89d217aecb2b9b5963c7dcf24b6236732a58f10112153013111dea3',
                taskcluster_proxy_version => 'v37.3.0',
                taskcluster_proxy_sha256  => 'd66356c33da0c4e48fd2a99191d2c7bc11a020bb9571c55b1e150b052fc536a4',
                livelog_version           => 'v37.3.0',
                livelog_sha256            => '7a4c8ef616ab3aee1e5494566d895dd44c09f7bb28d730d0de30717873a72b01',
                start_worker_version      => 'v37.3.0',
                start_worker_sha256       => '2a0c5d2809fa49b5d9de453834b2e56d9b8318aeb9925a8af1ccc2ce3d18eceb',
                quarantine_worker_version => 'v1.0.0',
                quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
                user                      => 'cltbld',
                user_homedir              => '/home/cltbld',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
