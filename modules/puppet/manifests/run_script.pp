# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class puppet::run_script (
    String $puppet_env          = 'production',
    String $puppet_repo         = 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
    String $puppet_branch       = 'master',
    String $puppet_notify_email = 'puppet-ronin-reports@mozilla.com',
    String $smtp_relay_host     = 'localhost',
) {

    # puppet is assumed present, include setup or other module if installation is desired

    case $::operatingsystem {
        'Ubuntu': {
            case $::operatingsystemrelease {
                '18.04': {
                    file {
                        '/usr/local/bin/run-puppet.sh':
                            owner   => 'root',
                            group   => 'root',
                            mode    => '0755',
                            content => template('puppet/puppet-ubuntu-run-puppet.sh.erb');
                    }
                }
                default: {
                    fail("puppet::run_script support missing for ${::operatingsystemrelease}")
                }
            }
        }
        default: {
            fail("${module_name} does not support ${::operatingsystem}")
        }
    }

}
