# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::error_reporting {

    $error_report_key = "HKLM\\SOFTWARE\\Microsoft\\Windows\\Windows\\Error\\Reporting"

    # Using puppetlabs-registry
    registry::value { 'LocalDumps' :
        key  => $error_report_key,
        type => dword,
        data => '1',
    }
    registry::value { 'DontShowUI' :
        key  => $error_report_key,
        type => dword,
        data => '1',
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1562024
