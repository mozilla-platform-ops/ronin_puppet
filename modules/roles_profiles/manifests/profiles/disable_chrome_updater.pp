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
                purge   => true,
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
                file { '/Library/Google/GoogleSoftwareUpdate':
                    ensure  => directory,
                    purge   => true,
                    force   => true,
                    recurse => true,
                    mode    => '0444',
                }
                file { '/Library/Caches/com.google.Keystone.agent':
                    ensure  => absent,
                }
                file { '/Library/LaunchAgents/com.google.Keystone.agent.plist':
                    ensure  => absent,
                }
            } else {
                exec {
                    'chrome-update-service-no-interval':
                        command     => 'defaults write com.google.Keystone.Agent checkInterval 0',
                }
                service {
                    [
                      'com.google.keystone.system.agent',
                      'com.google.keystone.system.xpcservice',
                    ]:
                        ensure => 'stopped',
                        enable => false,
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
