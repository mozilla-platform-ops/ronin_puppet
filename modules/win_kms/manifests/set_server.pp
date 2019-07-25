# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_kms::set_server (
    String $server,
    Integer $port = 1688
) {

    $kms_key = "HKLM\\SYSTEM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SoftwareProtectionPlatform"

    registry_value { "${kms_key}\\KeyManagementServiceName":
        type => string,
        data => $server,
    }
    registry_value { "${kms_key}\\KeyManagementServicePort":
        type => dword,
        data => $port,
    }
}
