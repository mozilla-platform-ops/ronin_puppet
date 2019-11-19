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

            # Template variables for script_config.yaml
            #   - taskcluster_scope_prefix
            #   - config file role name
            #   - sign_with_entitlements
            #   - verify_mac_signature
            #   - base_bundle_id
            #   - identity
            #   - keychain_password
            #   - pkg_cert_id
            #   - notarization_account
            #   - notarization_password
            #   - apple_asc_provider
            #   - notarization_poll_timeout
            #   - widevine_url
            #   - widevine_user
            #   - widevine_pass
            #   - omnija_url
            #   - omnija_user
            #   - omnija_pass
            #   - langpack_url
            #   - langpack_user
            #   - langpack_pass
            # Template variables for scriptworker.yaml
            #   - worker_type
            #   - taskcluster_access_token
            #   - taskcluster_client_id
            #   - sign_chain_of_trust
            #   - verify_chain_of_trust
            #   - verify_cot_signature

            # TODO Don't create these if the secrets service is unsatisfatory.
            # Cert files to create
            #   - dep:
            #     - widevine_dep.crt from signing_keys.widevine_dep_crt
            #     - dep_signing.keychain from signing_keys.dep_signing_keychain
            #  - default
            #    - widevine_prod.crt
            #    - nightly_signing.keychain
            #    - release-signing.keychain
            #    - ed25519_privkey
            #

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
