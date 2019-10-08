# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::disable_chrome_updater (
    Boolean $purge = true,
) {

    case $::operatingsystem {
        'Darwin': {
            # For new users (potentially created by multiuser generic-worker),
            # executing Chrome will install the updater and create a user launch agent to run updates.
            # We cannot block users from installing the updater.
            # Let's block creation of the user launchagent
            file { [ '/System/Library/User Template/English.lproj/Library/LaunchAgents' ]:
                ensure  => directory,
                force   => true,
                recurse => true,
                mode    => '0444',
            }
            file { '/System/Library/User Template/English.lproj/Library/LaunchAgents/com.google.keystone.agent.plist':
                ensure  => file,
                force   => true,
                mode    => '0444',
                content => '',
            }
            # For the cltbld user and the system (if Chrome was run by an admin),
            # purge the updater application and service,
            # or set the update interval to 0(never).
            if $purge {
                file { [ '/Library/Google',
                      '/Library/Google/GoogleSoftwareUpdate',
                      '/Users/cltbld/Library/Google',
                      '/Users/cltbld/Library/Google/GoogleSoftwareUpdate' ]:
                    ensure  => directory,
                    purge   => true,
                    force   => true,
                    recurse => true,
                    mode    => '0444',
                }
                file { [ '/Library/Caches/com.google.Keystone.agent',
                      '/Users/cltbld/Library/Caches/com.google.Keystone.agent',
                      '/Library/LaunchAgents/com.google.Keystone.agent.plist',
                      '/Users/cltbld/Library/LaunchAgents/com.google.Keystone.agent.plist' ]:
                    ensure => absent,
                    force  => true,
                }
            } else {
                exec {
                    'chrome-update-service-no-interval-system':
                        command => '/usr/bin/defaults write com.google.Keystone.Agent checkInterval 0',
                }
                exec {
                    'chrome-update-service-no-interval-cltbld':
                        command => '/usr/bin/sudo -u cltbld /usr/bin/defaults write com.google.Keystone.Agent checkInterval 0',
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
