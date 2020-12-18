# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_shared::take_own_reg_key (
    String $regkey
){


    exec { "take_${regkey}":
        command  => epp('win_shared/take_own_reg_key.ps1.epp'),
        provider => powershell,
    }
}
