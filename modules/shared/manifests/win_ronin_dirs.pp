# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class shared::win_ronin_dirs {

$roninprogramdata  = $facts['roninprogramdata']
$semaphoredir = $facts['roninsemaphoredir']

    # "$facts['roninprogramdata']"
    file { $roninprogramdata:
        ensure => directory,
    }
    # $facts['roninsemaphoredir']
    file { $semaphoredir:
        ensure => directory,
    }
}
