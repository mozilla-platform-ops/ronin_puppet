# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_shared::take_own_reg_key (
    $reg_key,
    $rname=$title
){

    $key_name = $reg_key

    exec { "take_${rname}":
        #command  => epp('win_shared/take_own_reg_key.ps1.epp'),
        content  => template('win_shared/take_own_reg_key.ps1.erb'),
        provider => powershell,
    }
    #file { "${facts['custom_win_roninprogramdata']}\\take_${$rname}.ps1":
        #content => template('win_shared/take_own_reg_key.ps1.erb'),
        #content => epp('win_shared/take_own_reg_key.ps1.epp'),
    #}
}
