# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::files_system_managment {

    case $::operatingsystem {
        'Windows': {
            include win_filesystem::disable8dot3
            include win_filesystem::disablelastaccess
            if $facts['custom_win_location'] == 'aws' {
                win_filesystem::set_paging_file { 'aws_paging_file':
                    location =>  'y:\pagefile.sys',
                    min_size => 8192,
                    max_size => 8192,
                }
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1515779
            # Paging file
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1562974
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
