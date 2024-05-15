# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::cltbld_user {
  case $facts['os']['name'] {
    'Darwin': {
      $account_username = 'cltbld'
      $password     = lookup('cltbld_user.password')
      # lookup('cltbld_user.unhashedpassword') does not work for some reason. Hard coding for now
      $password_unhashed    = 'cltbld'
      $salt         = lookup('cltbld_user.salt')
      $iterations   = lookup('cltbld_user.iterations')
      $kcpassword   = lookup('cltbld_user.kcpassword')
      $password_hash = inline_template("<%= IO.popen(['openssl', 'passwd', '-6', '-salt', '${salt}', '-6', '-rounds', '${iterations}', '${password}']).read.chomp %>")

      # Create the cltbld user
      case $facts['os']['release']['major'] {
        '19', '20', '21': {
          users::single_user { 'cltbld':
            # Bug 1122875 - cltld needs to be in this group for debug tests
            password   => $password,
            salt       => $salt,
            iterations => $iterations,
          }
          # Set user to autologin
          class { 'macos_utils::autologin_user':
            user       => 'cltbld',
            kcpassword => $kcpassword,
          }
          macos_utils::clean_appstate { 'cltbld':
            user  => 'cltbld',
            group => 'staff',
          }
          file { '/Users/cltbld/Library/LaunchAgents':
            ensure => directory,
          }
        }
        '22', '23': {
          exec { 'create_macos_user':
            # UID needs to be > 501 for LaunchAgents to function
            command => "/usr/sbin/sysadminctl -addUser ${account_username} -UID 555 -password '${password_hash}'",
            unless  => '/usr/bin/dscl . -read /Users/cltbld',
          }
          class { 'macos_utils::autologin_user':
            user       => $account_username,
            kcpassword => $password_unhashed,
          }
          macos_utils::clean_appstate_13_plus { 'cltbld':
            user  => 'cltbld',
            group => 'staff',
          }
        }
        default: {
          fail("${facts['os']['release']} not supported")
        }
      }

      #   Monkey patching directoryservice.rb in order to create users also breaks group merging
      #   So we directly add the user to the group(s)
      $groups = ['_developer','com.apple.access_screensharing','com.apple.access_ssh']
      $groups.each |String $group| {
        exec { "cltbld_group_${group}":
          command => "/usr/bin/dscl . -append /Groups/${group} GroupMembership cltbld",
          unless  => "/usr/bin/groups cltbld | /usr/bin/grep -q -w ${group}",
          #require => User['cltbld'],
        }
      }
      # Ensure the AuthenticationAuthority hash is set.  Puppet does not set this when creating a user.  Needed for GUI/VNC access.
      $auth_key_hash = '\';ShadowHash;HASHLIST:<SALTED-SHA512-PBKDF2,SRP-RFC5054-4096-SHA512-PBKDF2,SMB-NT>\''
      exec { 'cltbld_auth_key':
        command => "/usr/bin/dscl . -create /Users/cltbld AuthenticationAuthority ${auth_key_hash}",
        unless  => "/usr/bin/dscl . -read /Users/cltbld AuthenticationAuthority| grep -q -w ${auth_key_hash}",
        #require => User['cltbld'],
      }

      # Enable DevToolsSecurity
      include macos_utils::enable_dev_tools_security

      mercurial::hgrc { '/Users/cltbld/.hgrc':
        user  => 'cltbld',
        group => 'staff',
        # require => User['cltbld'],
      }

      $sudo_commands = ['/sbin/reboot']
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
        name      => 'cltbld',
      }

      # Create the cltbld user
      users::single_user { 'cltbld':
        # Bug 1122875 - cltld needs to be in this group for debug tests
        password   => $password,
        salt       => $salt,
        iterations => $iterations,
        groups     => ['audio','video'],
      }

      # conflicts with /etc/mercurial/hgrc
      file {
        '/home/cltbld/.hgrc':
          ensure => absent;
      }

      sudo::custom { 'allow_cltbld_reboot':
        user    => 'cltbld',
        command => '/sbin/reboot',
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
