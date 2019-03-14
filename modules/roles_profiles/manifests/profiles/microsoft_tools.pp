# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::microsoft_tools {

    case $::operatingsystem {
        'Windows': {

            # These may chnage for diffrent versions of Windows
            $moz_profile_source = 'http://hg.mozilla.org/mozilla-central/raw-file/360ab7771e27/toolkit/components/startup/mozprofilerprobe.mof'
            $moz_profile_file   = "${facts['custom_win_programfilesx86']}\
\\Windows Kits\\10\\Windows Performance Toolkit\\mozprofilerprobe.mof"

            include win_packages::vc_redist_x86
            include win_packages::vc_redist_x64
            include win_os_settings::powershell_profile

            class { 'win_packages::performance_tool_kit':
                moz_profile_source => $moz_profile_source,
                moz_profile_file   => $moz_profile_file,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1510837
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
