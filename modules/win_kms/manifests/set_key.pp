# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_kms::set_key (
    String $key
) {

    exec { 'set_kms_key':
        command  => epp('win_kms/set_kms_key.ps1'),
        provider => 'powershell',
    }

}
