# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::disable_chrome_updater (
    Boolean $purge = true,
) {

    case $::operatingsystem {
        'Darwin': {
            file { [ '/System/Library/User Template/English.lproj/Library/LaunchAgents',
                  '/System/Library/User Template/English.lproj/Library/Google',
                  '/System/Library/User Template/English.lproj/Library/Google/GoogleSoftwareUpdate' ]:
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
                      '/Users/cltbld/Library/Caches/com.google.Keystone.agent' ]:
                    ensure => absent,
                    force  => true,
                }
                file { [ '/Library/LaunchAgents/com.google.Keystone.agent.plist',
                      '/Users/cltbld/Library/LaunchAgents/com.google.Keystone.agent.plist' ]:
                    ensure => absent,
                    force  => true,
                }
            } else {
                exec {
                    'chrome-update-service-no-interval':
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
