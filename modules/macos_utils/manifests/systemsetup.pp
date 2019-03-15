# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::systemsetup (
    String $setting,
    String $option = $title,
) {

    $cmd = '/usr/sbin/systemsetup'

    exec { "macos_systemsetup -set${title} ${setting}" :
        command => "${cmd} -set${title} ${setting}",
        unless  => "${cmd} -get${title} | awk -F \": \" \'{print \$2}\' | grep -i ${setting}",
    }
}
