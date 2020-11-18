# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_1_b_osx_1015_generic_worker (
    String $worker_type = 'gecko-1-b-osx-1015',
) {
    class { 'roles_profiles::profiles::cltbld_user':
        autologin => false,
    }

    $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

    $meta_data        = {
        workerType    => $worker_type,
        workerGroup   => $worker_group,
        provisionerId => 'releng-hardware',
        workerId      => $facts['networking']['hostname'],
    }

    case $::operatingsystem {
        'Darwin': {

            class { 'puppet::atboot':
                telegraf_user       => lookup('telegraf.user'),
                telegraf_password   => lookup('telegraf.password'),
                puppet_env          => 'dev',
                puppet_repo         => 'https://github.com/davehouse/ronin_puppet.git',
                puppet_branch       => 'bug1665379_mac-builders-test-multi',
                puppet_notify_email => 'dhouse@mozilla.com',
                meta_data           => $meta_data,
            }

            class { 'roles_profiles::profiles::logging':
                worker_type   => $worker_type,
                mac_log_level => 'default',
            }

            class { 'telegraf':
                global_tags  => $meta_data,
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
                        exe      => 'generic-worker',
                    },
                },
            }

            class { 'talos':
                user => 'cltbld',
            }

            $taskcluster_client_id    = lookup('generic_worker.datacenter_gecko_1_b_osx_1015.taskcluster_client_id')
            $taskcluster_access_token = lookup('generic_worker.datacenter_gecko_1_b_osx_1015.taskcluster_access_token')
            $livelog_secret           = lookup('generic_worker.datacenter_gecko_1_b_osx_1015.livelog_secret')
            $quarantine_client_id     = lookup('generic_worker.datacenter_gecko_1_b_osx_1015.quarantine_client_id')
            $quarantine_access_token  = lookup('generic_worker.datacenter_gecko_1_b_osx_1015.quarantine_access_token')
            $bugzilla_api_key         = lookup('generic_worker.datacenter_gecko_1_b_osx_1015.bugzilla_api_key')

            class { 'packages::zstandard':
                version => '1.3.8',
            }

            class { 'generic_worker::multiuser':
                taskcluster_client_id     => $taskcluster_client_id,
                taskcluster_access_token  => $taskcluster_access_token,
                worker_group              => $worker_group,
                worker_type               => $worker_type,
                data_dir                  => '/var/opt/generic-worker',
                generic_worker_version    => 'v38.0.4',
                generic_worker_sha256     => '5b97f98d52b97e2114b29ac42a0fcefb7b90ef70d1e24a3bbd6572a7ee6d4807',
                taskcluster_proxy_version => 'v38.0.4',
                taskcluster_proxy_sha256  => 'dd3095ee5aaa8c5fc017207f85bcb49fd83d429a759b07d82f6c0cb1c1b23fd7',
                livelog_version           => 'v38.0.4',
                livelog_sha256            => '2aef4bfbc214f1bece2154ee5ec5eedf9e495b562476873a759b229e25c3b448',
                user                      => 'root',
                #gw_dir                    => '/etc/generic-worker',
            }

            # exec { 'writes_in_catalina':
            #     command => '/sbin/mount -uw /',
            #     unless  => '/bin/test -d /builds || /bin/test -d /tools'
            # }
            #include dirs::tools

            #include packages::google_chrome
            #file { '/var/opt/generic-worker':
            #    ensure => 'directory',
            #    mode   => '0755',
            #}

            contain packages::nodejs
            #contain packages::wget
            contain packages::tooltool
            file { '/tools/tooltool.py':
                ensure  => 'link',
                target  => '/usr/local/bin/tooltool.py',
                require => Class['packages::tooltool'],
            }

            contain packages::mercurial
            contain mercurial::system_hgrc

            contain packages::python2
            # python2::user_pip_conf { 'cltbld_user_pip_conf':
            #     user  => 'cltbld',
            #     group => 'staff',
            # }

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
