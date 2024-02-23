# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::cltbld_user {
  case $facts['os']['name'] {
    'Darwin': {
      $account_username = 'cltbld'
      $password     = lookup('cltbld_user.password')
      $password2    = 'cltbld'
      # 470e6911fc53dcfa69f3d33f31db64d2b1f57d4067913988bc015beb15c860ffced8b8b120f146ebd8e8db3ad412656e074c3178a9b2e4b2a2978eb2eeb4bd8449a6a8a377ddb5a1645976b2e41a1d1ae078918b4ea88ef9b28d00a2e3cdeca2190134cadeabadc8af9d10112d46e359242c4261d32c99ecb3b5dd140d6536b1
      $salt         = lookup('cltbld_user.salt')
      # 5877bddcd949164d908f8c36b284b27e1261570db303cd708a38f6745e1d2aa2
      $iterations   = lookup('cltbld_user.iterations')
      # 40000
      $kcpassword   = lookup('cltbld_user.kcpassword')
      # DeghUKXTr46juR8=

      # this can be used for line 45 but its just a theory. auto login succeeds
      $password_hash = inline_template("<%= IO.popen(['openssl', 'passwd', '-6', '-salt', '${salt}', '-6', '-rounds', '${iterations}', '${password}']).read.chomp %>")

      # Create the cltbld user
      case $facts['os']['release']['major'] {
        '19', '20': {
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
          file { '/Users/cltbld/Library/':
            ensure => directory,
          }
        }
        '22', '23': {
          # Account creation on macOS 13+
          exec { 'create_home_directory':
            command => "/bin/mkdir -p /Users/${account_username}",
            unless  => "/bin/test -d /Users/${account_username}",
          }

          # acl { '/Users/cltbld/':
          #   permissions => [
          #     {
          #       identity  => 'everyone',
          #       rights    => ['read', 'execute'],
          #       perm_type => 'allow',
          #       affects   => 'all',
          #     },
          #   ],
          # }
          # exec { 'set_acl_home_directory':
          #   command => "chmod -a 'group:everyone deny delete' /Users/cltbld",
          # }
          # kcpassword does NOT seem to work here for autologin (while also setting line 57 dynamically)
          exec { 'create_macos_user':
            command => "/usr/sbin/sysadminctl -addUser ${account_username} -fullName '${account_username}' -password '${password_hash}' -home /Users/${account_username}",
            unless  => '/usr/bin/dscl . -read /Users/cltbld',
          }
          # # Something starting here causes the LoginItems breakage
          # file { "/Users/${account_username}/Library/":
          #   ensure  => 'directory',
          #   owner   => 'cltbld',
          #   group   => 'staff',
          #   mode    => '0700',
          #   content => '',
          #   #require => File["/Users/${account_username}"];
          # }

          # acl { '/Users/cltbld/Library/':
          #   permissions => [
          #     {
          #       identity  => 'everyone',
          #       rights    => ['read', 'execute'],
          #       perm_type => 'allow',
          #       affects   => 'all',
          #     },
          #   ],
          # }

          # file { "/Users/${account_username}/Library/Preferences":
          #   ensure  => 'directory',
          #   owner   => 'cltbld',
          #   group   => 'staff',
          #   mode    => '0700',
          #   content => '',
          #   require => File["/Users/${account_username}/Library/"];
          # }

          # acl { '/Users/cltbld/Library/Preferences/':
          #   permissions => [
          #     {
          #       identity  => 'everyone',
          #       rights    => ['read', 'execute'],
          #       perm_type => 'allow',
          #       affects   => 'all',
          #     },
          #   ],
          # }

          # file {
          #   "/Users/${account_username}/Library/Saved Application State":
          #     ensure  => directory,
          #     owner   => $account_username,
          #     group   => $group,
          #     mode    => '0500', # remove write permission
          #     require => Exec['create_macos_user'];
          # }

          # file {
          #   "/Users/${account_username}/Library/Preferences/.GlobalPreferences.plist":
          #     ensure  => file,
          #     owner   => $account_username,
          #     group   => $group,
          #     mode    => '0600',
          #     require => Exec['create_macos_user'];
          # }

          # tidy {
          #   "/Users/${account_username}/Library/Saved Application State":
          #     matches => '*.savedState',
          #     rmdirs  => true,
          #     recurse => true,
          #     require => Exec['create_macos_user'];
          # }

          # file { "/Users/${account_username}/Library/Preferences/ByHost/com.apple.loginwindow.${::facts[system_profiler][hardware_uuid]}.plist":
          #   ensure  => 'file',
          #   owner   => 'root',
          #   group   => 'wheel',
          #   mode    => '0000',
          #   content => '',
          #   #require => File["/Users/${account_username}/Library/Preferences/ByHost"];
          # }

          # TODO: Suppress accessibility window

          # exec { 'set_auto_login':
          #   command => "/usr/sbin/sysadminctl -autologin set -userName '${account_username}' -password 'password1'",
          #   # unless  => '/usr/bin/dscl . -read /Users/cltbld',
          # }
          # I don't know why the next few lines work but it does
          # Set user to autologin
          class { 'macos_utils::autologin_user':
            user       => $account_username,
            kcpassword => $password2,
          }
          macos_utils::clean_appstate2 { 'cltbld':
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

      # # Set user to autologin
      # class { 'macos_utils::autologin_user':
      #   user       => 'cltbld',
      #   kcpassword => $kcpassword,
      # }

      # Ensure the AuthenticationAuthority hash is set.  Puppet does not set this when creating a user.  Needed for GUI/VNC access.
      $auth_key_hash = '\';ShadowHash;HASHLIST:<SALTED-SHA512-PBKDF2,SRP-RFC5054-4096-SHA512-PBKDF2,SMB-NT>\''
      exec { 'cltbld_auth_key':
        command => "/usr/bin/dscl . -create /Users/cltbld AuthenticationAuthority ${auth_key_hash}",
        unless  => "/usr/bin/dscl . -read /Users/cltbld AuthenticationAuthority| grep -q -w ${auth_key_hash}",
        #require => User['cltbld'],
      }

      # Enable DevToolsSecurity
      include macos_utils::enable_dev_tools_security

      # macos_utils::clean_appstate { 'cltbld':
      #   user  => 'cltbld',
      #   group => 'staff',
      # }

      mercurial::hgrc { '/Users/cltbld/.hgrc':
        user  => 'cltbld',
        group => 'staff',
        # require => User['cltbld'],
      }

      # file { '/Users/cltbld/Library/LaunchAgents':
      #   ensure => directory,
      # }

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
