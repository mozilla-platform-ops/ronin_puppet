# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_talos_generic_worker {

    # TODO: make these args to this module and use in call in gecko_t_linux_talos?
    $worker_type  = 'gecko-t-linux-talos-1804'
    $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

    case $::operatingsystem {
        'Ubuntu': {
            require roles_profiles::profiles::cltbld_user

            class { 'roles_profiles::profiles::logging_papertrail':
                papertrail_host    => lookup( { 'name' => 'papertrail.host', 'default_value' => '' } ),
                papertrail_port    => lookup( { 'name' => 'papertrail.port', 'default_value' => -1 } ),
                systemd_units      => ['check_gw', 'run-puppet', 'ssh'],
                syslog_identifiers => ['generic-worker', 'run-start-worker', 'sudo'],
            }

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

            # moved from base to avoid ordering issues with py2/3
            include linux_mercurial

            require linux_talos

            class { 'puppet::atboot':
                telegraf_user     => lookup('telegraf.user'),
                telegraf_password => lookup('telegraf.password'),
                puppet_repo       => 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
                puppet_branch     => 'master',
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
                generic_worker_version    => 'v44.23.2',
                generic_worker_sha256     => '4b65b06281848749500063a53190d0222372fe7252ef77f935081bfbfa915ebe',
                taskcluster_proxy_version => 'v44.23.2',
                taskcluster_proxy_sha256  => 'af0559355a607ecc933e0109b12c187c2d7679a4b9b0044ad1c43b122000e3c5',
                livelog_version           => 'v44.23.2',
                livelog_sha256            => '0adbad0397aa608f4b826bff0dc504d2f9f4efba6474ec4c0d8f8ee22cf2ee90',
                start_worker_version      => 'v44.23.2',
                start_worker_sha256       => '05b00bbca08477d79613025ee877b8f0a925ab3c6063ef62316c9017ccce5881',
                quarantine_worker_version => 'v1.0.0',
                quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
                user                      => 'cltbld',
                user_homedir              => '/home/cltbld',
            }

            require linux_generic_worker::check_gw

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
