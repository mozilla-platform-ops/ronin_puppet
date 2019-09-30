# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_osx_1014_generic_worker {

    require roles_profiles::profiles::cltbld_user

    $worker_type  = 'gecko-t-osx-1014'
    $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

    case $::operatingsystem {
        'Darwin': {

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

            class { 'roles_profiles::profiles::logging':
                worker_type => $worker_type,
            }

            class { 'talos':
                user => 'cltbld',
            }

            $taskcluster_client_id    = lookup('generic_worker.gecko_t_osx_1014.taskcluster_client_id')
            $taskcluster_access_token = lookup('generic_worker.gecko_t_osx_1014.taskcluster_access_token')
            $livelog_secret           = lookup('generic_worker.gecko_t_osx_1014.livelog_secret')
            $quarantine_client_id     = lookup('generic_worker.gecko_t_osx_1014.quarantine_client_id')
            $quarantine_access_token  = lookup('generic_worker.gecko_t_osx_1014.quarantine_access_token')
            $bugzilla_api_key         = lookup('generic_worker.gecko_t_osx_1014.bugzilla_api_key')

            class { 'packages::zstandard':
                version => '1.3.8',
            }

            class { 'generic_worker':
                taskcluster_client_id     => $taskcluster_client_id,
                taskcluster_access_token  => $taskcluster_access_token,
                livelog_secret            => $livelog_secret,
                worker_group              => $worker_group,
                worker_type               => $worker_type,
                quarantine_client_id      => $quarantine_client_id,
                quarantine_access_token   => $quarantine_access_token,
                bugzilla_api_key          => $bugzilla_api_key,
                generic_worker_version    => 'v13.0.3',
                generic_worker_sha256     => '6e5c1543fb3c333ca783d0a5c4e557b2b5438aada4bc23dc02402682ae4e245e',
                taskcluster_proxy_version => 'v5.1.0',
                taskcluster_proxy_sha256  => '3faf524b9c6b9611339510797bf1013d4274e9f03e7c4bd47e9ab5ec8813d3ae',
                quarantine_worker_version => 'v1.0.0',
                quarantine_worker_sha256  => '60bb15fa912589fd8d94dbbff2e27c2718eadaf2533fc4bbefb887f469e22627',
                user                      => 'cltbld',
                user_homedir              => '/Users/cltbld',
            }

            include dirs::tools

            class { 'packages::google_chrome':
                version => 'v76.0.3809.132',
            }
            include roles_profiles::profiles::disable_chrome_updater

            contain packages::nodejs
            contain packages::wget
            contain packages::tooltool
            file { '/tools/tooltool.py':
                ensure  => 'link',
                target  => '/usr/local/bin/tooltool.py',
                require => Class['packages::tooltool'],
            }

            contain packages::mercurial
            contain mercurial::system_hgrc

            contain packages::python2
            python2::user_pip_conf { 'cltbld_user_pip_conf':
                user  => 'cltbld',
                group => 'staff',
            }

            file {
                '/tools/python':
                    ensure  => 'link',
                    target  => '/usr/local/bin/python2',
                    require => Class['packages::python2'];

                '/tools/python2':
                    ensure  => link,
                    target  => '/usr/local/bin/python2',
                    require => Class['packages::python2'];
            }

            contain packages::python3
            file { '/tools/python3':
                    ensure  => 'link',
                    target  => '/usr/local/bin/python3',
                    require => Class['packages::python3'],
            }

            contain packages::virtualenv

            contain packages::python2_zstandard
            contain packages::python3_zstandard

            include mercurial::ext::robustcheckout
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
