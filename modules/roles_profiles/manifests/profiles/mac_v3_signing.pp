# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mac_v3_signing {

    case $::operatingsystem {
        'Darwin': {

            $worker_type  = 'mac-v3-signing'
            $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

            $role = $facts['networking']['hostname']? {
                /^dep-mac-v3-signing\d+/ => 'dep',
                /^tb-mac-v3-signing\d+/ => 'tb-prod',
                default => 'ff-prod',
            }

            include puppet::disable_atboot
            class { 'puppet::periodic:
                telegraf_user     => lookup('telegraf.user'),
                telegraf_password => lookup('telegraf.user'),
                puppet_repo       =>
                puppet_branch     =>
                meta_data         => {
                    workerType    => $worker_type,
                    workerGroup   => $worker_group,
                    # provisionerId => 'releng-hardware',
                    # workerId      => $facts['networking']['hostname'],
                    role          => $role,
                },
            }

            class { 'roles_profiles::profiles::logging':
                # The logging module tags the logs with:
                # hostname: hostname
                # workerId: short hostname
                # workerGroup: mdcN (3rd dot-separated string in fqdn)
                # workerType: $worker_type
                worker_type => $worker_type,
            }

            include dirs::tools

            class { 'scriptworker_prereqs': }

            # For cloning the widevine repository
            $widevine_user = lookup('widevine_config.user')
            $widevine_key = lookup('widevine_config.key')

            # Distinct names because vault's prefix is different.
            $worker_common = lookup("scriptworker_config.${role}", Hash, undef, {})
            $worker_secrets = lookup("scriptworker_secrets.${role}", Hash, undef, {})
            $worker_config = deep_merge($worker_common, $worker_secrets)

            $role_common = lookup("signingworker_roles.${role}", Hash, undef, {})
            $role_secrets = lookup("signing_secrets.${role}", Hash, undef, {})
            $role_config = deep_merge($role_common, $role_secrets)

            $poller_common = lookup("poller_config.${role}", Hash, undef, {})
            $poller_secrets = lookup("poller_secrets.${role}", Hash, undef, {})
            $poller_config = deep_merge($poller_common, $poller_secrets)

            $scriptworker_users = lookup("scriptworker_users.${role}")

            $scriptworker_users.each |String $user, Hash $user_data| {
                signing_worker { "signing_worker_${user}":
                    role                => $role,
                    user                => $user,
                    password            => lookup("${user}_user.password"),
                    salt                => lookup("${user}_user.salt"),
                    iterations          => lookup("${user}_user.iterations"),
                    scriptworker_base   => $user_data['home'],
                    dmg_prefix          => $user_data['dmg_prefix'],
                    worker_type_prefix  => $user_data['worker_type_prefix'],
                    worker_id_suffix    => $user_data['worker_id_suffix'],
                    cot_product         => $user_data['cot_product'],
                    supported_behaviors => $user_data['supported_behaviors'],
                    widevine_user       => $widevine_user,
                    widevine_key        => $widevine_key,
                    widevine_filename   => $user_data['widevine_filename'],
                    worker_config       => $worker_config,
                    role_config         => $role_config,
                    notarization_users  => $user_data['notarization_users'],
                    ed_key_filename     => $user_data['ed_key_filename'],
                    poller_config       => $poller_config,
                }
            }

            class { 'telegraf':
                global_tags  => {
                    workerType    => $worker_type,
                    workerGroup   => $worker_group,
                    provisionerId => 'scriptworker-prov-v1',
                    role          => $role,
                    workerId      => $facts['networking']['hostname'],
                },
                agent_params => {
                    interval          => '300s',
                    round_interval    => true,
                    collection_jitter => '0s',
                    precision         => 's',
                },
                inputs       => {
                    # current default telegraf monitors: system, mem, swap, disk'/', puppetagent
                    system      => {},
                    temp        => {},
                    cpu         => {
                        interval         => '60s',
                        percpu           => true,
                        totalcpu         => true,
                        ## If true, collect raw CPU time metrics.
                        collect_cpu_time => false,
                        ## If true, compute and report the sum of all non-idle CPU states.
                        report_active    => false,
                    },
                    mem         => {},
                    swap        => {},
                    disk        => {
                        mount_points => ['/'],
                    },
                    diskio      => {},
                    procstat    => {
                        interval => '60s',
                        exe      => '/builds/scriptworker/bin/scriptworker',
                    },
                    procstat2   => {
                        plugin_type => 'procstat',
                        interval    => '60s',
                        pattern     => 'tools/release/signing/signing-server.py',
                    },
                    puppetagent => {
                        location => '/opt/puppetlabs/puppet/cache/state/last_run_summary.yaml',
                    },
                },
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
