# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::rosetta_2 {

    if $facts['system_profiler']['model_identifier'] == 'Macmini9,1' {
        exec { 'install_rosetta_2':
            command => '/usr/sbin/softwareupdate install-rosetta agree-to-license',
            unless  => '/bin/test -f /Library/Apple/System/Library/LaunchDaemons/com.apple.oahd.plist',
        }
    } else {
        fail("${module_name}: Cannot install Rosetta 2 on ${facts['system_profiler']['model_identifier']}")
    }
}
