# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mac_v3_signing {

    case $::operatingsystem {
        'Darwin': {

            $worker_type  = 'mac-v3-signing'
            $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

            # TODO: mac-v3-signing should run puppet more than just at boot.
            # This needs a puppet::periodic class for running puppet on a cron schedule
            class { 'puppet::atboot':
                telegraf_user     => lookup('telegraf.user'),
                telegraf_password => lookup('telegraf.password'),
                # Note the camelCase key names
                meta_data         => {
                    workerType    => $worker_type,
                    workerGroup   => $worker_group,
                    provisionerId => 'none',
                    workerId      => $facts['networking']['hostname'],
                },
                # "pinning"
                # for the first setup of a node type, the provisioner script in the image must have a valid node
                # then, pinning will apply on the next run atboot:
                #puppet_repo   => 'https://github.com/davehouse/ronin_puppet.git',
                #puppet_branch => 'notarization',
            }

            # we can add worker setup here like in gecko_t_osx_1014_generic_worker.pp

            include dirs::tools
            class { 'scriptworker_prereqs': }

            case $::hostname {
                /^dep-mac-v3-signing\d+/: {
                    class { 'signing_worker':
                        user              => 'depbld1',
                        scriptworker_base => '/builds/dep1',
                        dmg_prefix        => 'dep1',
                        worker_id_suffix  => 'a',
                        cot_product       => 'firefox',
                    }
                    class { 'signing_worker':
                        user              => 'depbld2',
                        scriptworker_base => '/builds/dep2',
                        dmg_prefix        => 'dep2',
                        worker_id_suffix  => 'b',
                        cot_product       => 'firefox',
                    }
                    class { 'signing_worker':
                        user              => 'tbbld',
                        scriptworker_base => '/builds/tb-dep',
                        dmg_prefix        => 'tb',
                        worker_id_suffix  => 'tb',
                        cot_product       => 'thunderbird',
                    }

                }
                /^tb-mac-v3-signing\d+/: {
                    class { 'signing_worker':
                        cot_product => 'thunderbird',
                    }
                }
                default: {
                    class { 'signing_worker': }
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
