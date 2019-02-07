# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::files_system_managment {

    case $::operatingsystem {
        'Windows': {

            $system32 = $facts[system32]
            $fsutil   = "${system32}\\fsutil.exe"

            defined_classes::exec::execonce { 'fsutildisablelastaccess':
                command => "${fsutil} behavior set disablelastaccess 1",
            }
            defined_classes::exec::execonce { 'fsutildisable8dot3':
                command => "${fsutil} behavior set disable8dot3 1",
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1515779
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
