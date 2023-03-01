# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_shared::win_ronin_dirs {

if $::operatingsystem == 'Windows' {
    $roninprogramdata  = $facts['custom_win_roninprogramdata']
    $semaphoredir      = $facts['custom_win_roninsemaphoredir']
    $logdir            = $facts['custom_win_roninslogdir']

        # "$facts['custom_win_roninprogramdata']"
        file { $roninprogramdata:
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
    } else {
        fail("class shared::win_ronin_dirs does not support ${::operatingsystem}")
    }
}
