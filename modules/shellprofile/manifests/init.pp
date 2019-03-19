# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class shellprofile {

    include shellprofile::settings

    case $::operatingsystem {
        'Darwin': {
            file {
                $shellprofile::settings::profile_d:
                    ensure => directory;

                $shellprofile::settings::profile_puppet_d:
                    ensure  => directory,
                    purge   => true,
                    recurse => true,
                    force   => true;

                "${shellprofile::settings::profile_d}/puppetdir.sh":
                    mode    => '0755',
                    content => template('shellprofile/puppetdir.sh.erb');
            }

            # patch /etc/profile to run /etc/profile.d/*.sh
            file { '/etc/profile':
                source => 'puppet:///modules/shellprofile/darwin-profile';
            }
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
