# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::applicationservices_1_b_osx_1015_generic_worker {
    $worker_type = 'applicationservices-b-1-osx1015'

    $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

    $meta_data        = {
        workerType    => $worker_type,
        workerGroup   => $worker_group,
        provisionerId => 'releng-hardware',
        workerId      => $facts['networking']['hostname'],
    }

    case $facts['os']['name'] {
        'Darwin': {

            class { 'puppet::atboot':
                telegraf_user       => lookup('telegraf.user'),
                telegraf_password   => lookup('telegraf.password'),
                puppet_env          => 'dev',
                puppet_repo         => 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
                puppet_branch       => 'master',
                puppet_notify_email => 'relops-puppet-alerts@mozilla.com',
                meta_data           => $meta_data,
            }

            class { 'roles_profiles::profiles::logging':
                worker_type      => $worker_type,
                tail_worker_logs => true,
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

            $taskcluster_client_id    = lookup('generic_worker.taskcluster_client_id')
            $taskcluster_access_token = lookup('generic_worker.taskcluster_access_token')
            $livelog_secret           = lookup('generic_worker.livelog_secret')
            $quarantine_client_id     = lookup('generic_worker.quarantine_client_id')
            $quarantine_access_token  = lookup('generic_worker.quarantine_access_token')
            $bugzilla_api_key         = lookup('generic_worker.bugzilla_api_key')

            class { 'packages::zstandard':
                version => '1.3.8',
            }

            class { 'generic_worker::multiuser':
                taskcluster_client_id     => $taskcluster_client_id,
                taskcluster_access_token  => $taskcluster_access_token,
                worker_group              => $worker_group,
                worker_type               => $worker_type,
                data_dir                  => '/var/opt/generic-worker',
                generic_worker_version    => 'v52.0.0',
                generic_worker_sha256     => '9a25269cb998633d6ce1e959a480cde1723acaf17712fdfc38f640afa9e56232',
                taskcluster_proxy_version => 'v52.0.0',
                taskcluster_proxy_sha256  => '24d3879e85a923b71fb1d65950c16188eddd623a023c13f8e4b575b1a9cc0113',
                livelog_version           => 'v52.0.0',
                livelog_sha256            => 'fcd97d30d20d7e90498d91512560df104c82801879fd83d12cf9d1e94621372f',
                user                      => 'root',
                #gw_dir                    => '/etc/generic-worker',
            }

            exec { 'writes_in_catalina':
                command => '/sbin/mount -uw /',
                unless  => '/bin/test -d /builds || /bin/test -d /tools'
            }
            include dirs::tools
            include dirs::builds

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
            fail("${facts['os']['name']} not supported")
        }
    }
}
