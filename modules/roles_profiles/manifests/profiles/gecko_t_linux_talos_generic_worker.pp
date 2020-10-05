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
            require linux_packages::zstd

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

            require linux_talos

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
                generic_worker_version    => 'v37.2.0',
                generic_worker_sha256     => '60d83d76a3f8382e962fa56f91def45b195364837a3b35ac3cba5c15c32c301a',
                taskcluster_proxy_version => 'v37.2.0',
                taskcluster_proxy_sha256  => 'de3c953ffd9ea6e2c8604d64c22ce6ce9850600f546d88414e14409dd81e16d2',
                livelog_version           => 'v37.2.0',
                livelog_sha256            => '953c52bb6be9d1e816d56d972e8b306038ad48e6630e5bcb153052797eb20fea',
                quarantine_worker_version => 'v1.0.0',
                quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
                user                      => 'cltbld',
                user_homedir              => '/home/cltbld',
            }

            # TODO:
            # - talos: apache installation
            #   - set up g-w apache proxy
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
