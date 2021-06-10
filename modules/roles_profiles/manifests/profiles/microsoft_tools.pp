# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::microsoft_tools {

    case $::operatingsystem {
        'Windows': {

            # These may chnage for diffrent versions of Windows
            # TODO: Research why we are using a pinned version and add comment why.
            # Original source 'https://hg.mozilla.org/mozilla-central/raw-file/360ab7771e27/toolkit/components/startup/mozprofilerprobe.mof'
            # When pulling from a HG repo Puppet see it the file as a new file one ach run
            # In this case triggers the exec and adds to the local WMI repo each time
            # For now pulling from S3

            include win_packages::vc_redist_x86
            include win_packages::vc_redist_x64
            include win_os_settings::powershell_profile

            class { 'win_packages::performance_tool_kit':
                moz_profile_source => lookup('win-worker.mozilla_profile.source'),
                moz_profile_file   => lookup('win-worker.mozilla_profile.local'),
            }
            if $facts['custom_win_release_id'] == '2004'{
                include win_packages::cppbuildtools
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1510837
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
