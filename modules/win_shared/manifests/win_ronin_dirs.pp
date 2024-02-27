# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_shared::win_ronin_dirs {
  case $facts['custom_win_os_version'] {
    'win_11_2009', 'win_2022_2009', 'win_10_2009': {
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
    }
    default: {
      fail("${module_name} does not support ${$facts['custom_win_os_version']}")
    }
  }
}
