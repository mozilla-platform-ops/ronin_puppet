# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::cltbld_user (
    Array[String] $groups        = ['_developer','com.apple.access_screensharing','com.apple.access_ssh'],
    Array[String] $sudo_commands = ['/sbin/reboot'],
) {

    case $::operatingsystem {
        'Darwin': {
            $password     = lookup('cltbld_user.password')
            $salt         = lookup('cltbld_user.salt')
            $iterations   = lookup('cltbld_user.iterations')
            $kcpassword   = lookup('cltbld_user.kcpassword')

            # Create the cltbld user
            users::single_user { 'cltbld':
                # Bug 1122875 - cltld needs to be in this group for debug tests
                password   => $password,
                salt       => $salt,
                iterations => $iterations,
            }

            # Monkey patching directoryservice.rb in order to create users also breaks group merging
            # So we directly add the user to the group(s)
            $groups.each |String $group| {
                exec { "cltbld_group_${group}":
                    command => "/usr/bin/dscl . -append /Groups/${group} GroupMembership cltbld",
                    unless  => "/usr/bin/groups cltbld | /usr/bin/grep -q -w ${group}",
                    require => User['cltbld'],
                }
            }

            # Set user to autologin
            class { 'macos_utils::autologin_user':
                user       => 'cltbld',
                kcpassword => $kcpassword,
            }

            # Enable DevToolsSecurity
            include macos_utils::enable_dev_tools_security

            macos_utils::clean_appstate { 'cltbld':
                user  => 'cltbld',
                group => 'staff',
            }

            mercurial::hgrc { '/Users/cltbld/.hgrc':
                user    => 'cltbld',
                group   => 'staff',
                require => User['cltbld'],
            }

            $sudo_commands.each |String $command| {
                sudo::custom { "allow_cltbld_${command}":
                    user    => 'cltbld',
                    command => $command,
                }
            }
        }
        'Ubuntu': {
            $password     = lookup('cltbld_user.password')
            $salt         = lookup('cltbld_user.salt')
            $iterations   = lookup('cltbld_user.iterations')

            $username     = 'cltbld'
            $group        = 'cltbld'
            $homedir      = '/home/cltbld'

            group { 'cltbld':
                name      => 'cltbld'
            }

            # Create the cltbld user
            users::single_user { 'cltbld':
                # Bug 1122875 - cltld needs to be in this group for debug tests
                password   => $password,
                salt       => $salt,
                iterations => $iterations,
                groups     => ['audio','video']
            }

            mercurial::hgrc { '/home/cltbld/.hgrc':
                user    => 'cltbld',
                group   => 'staff',
                require => User['cltbld'],
            }

            sudo::custom { 'allow_cltbld_reboot':
                user    => 'cltbld',
                command => '/sbin/reboot',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
