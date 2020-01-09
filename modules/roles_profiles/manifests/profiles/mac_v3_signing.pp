# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mac_v3_signing {

    case $::operatingsystem {
        'Darwin': {

            $worker_type  = 'mac-v3-signing'
            $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

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

            $role = $facts['networking']['hostname']? {
                /^dep-mac-v3-signing\d+/ => 'dep',
                /^tb-mac-v3-signing\d+/ => 'tb-prod',
                default => 'ff-prod',
            }

            # Distinct names because vault's prefix is different.
            $worker_common = lookup("scriptworker_config.${role}", Hash, undef, {})
            $worker_secrets = lookup("scriptworker_secrets.${role}", Hash, undef, {})
            $worker_config = deep_merge($worker_common, $worker_secrets)

            $role_common = lookup("signingworker_roles.${role}", Hash, undef, {})
            $role_secrets = lookup("signing_secrets.${role}", Hash, undef, {})
            $role_config = deep_merge($role_common, $role_secrets)

            $scriptworker_users = lookup("scriptworker_users.${role}")

            $scriptworker_users.each |String $user, Hash $user_data| {
                signing_worker { "signing_worker_${user}":
                    user                => $user,
                    password            => lookup("${user}_user.password"),
                    salt                => lookup("${user}_user.salt"),
                    iterations          => lookup("${user}_user.iterations"),
                    scriptworker_base   => $user_data['home'],
                    dmg_prefix          => $user_data['dmg_prefix'],
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
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
