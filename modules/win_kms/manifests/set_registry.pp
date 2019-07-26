# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_kms::set_registry (
    String $server,
    String $key,
    Integer $port = 1688
) {

    $kms_key = "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SoftwareProtectionPlatform"

    registry_value { "${kms_key}\\KeyManagementServiceName":
        type => string,
        data => $server,
    }
    registry_value { "${kms_key}\\KeyManagementServicePort":
        type => dword,
        data => $port,
    }
    registry_value { "${kms_key}\\BackupProductKeyDefault":
        type => string,
        data => $key,
    }
}
