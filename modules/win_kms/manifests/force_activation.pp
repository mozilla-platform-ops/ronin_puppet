# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_kms::force_activation (
    String $server,
    String $key,
    Integer $port = 1688
) {

    exec { 'kms_activation':
        command  => epp('win_kms/force_kms_activation.ps1.epp'),
        provider => powershell,
    }
}
