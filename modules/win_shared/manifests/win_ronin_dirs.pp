# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_shared::win_ronin_dirs {
  case $facts['os']['name'] {
    'Windows': {
      $roninprogramdata  = $facts['custom_win_roninprogramdata']
      $semaphoredir      = $facts['custom_win_roninsemaphoredir']
      $logdir            = $facts['custom_win_roninslogdir']

      # "$facts['custom_win_roninprogramdata']"
      file { $roninprogramdata:
        ensure => directory,
      }
      file { "${$roninprogramdata}\\ronin":
        ensure => directory,
      }
      # $facts['custom_win_roninsemaphoredir']
      file { $semaphoredir:
        ensure => directory,
      }
      # $facts['custom_win_roninlogdir']
      file { $logdir:
        ensure => directory,
      }

      acl { [$roninprogramdata, "${roninprogramdata}\\ronin", $semaphoredir]:
        owner                      => 'S-1-5-18',
        inherit_parent_permissions => false,
        purge                      => true,
        permissions                => [
          { identity => 'S-1-5-18', rights => ['full'] },
          { identity => 'S-1-5-32-544', rights => ['full'] },
          { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
        ],
        require                    => File[$roninprogramdata, "${roninprogramdata}\\ronin", $semaphoredir],
      }
    }
    default: {
      fail("${module_name} does not support ${$facts['os']['name']}")
    }
  }
}
