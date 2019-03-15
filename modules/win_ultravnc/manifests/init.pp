# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_ultravnc (
    String  $package,
    String  $msi,
    String  $ini_file,
    String  $pw_hash,
    Integer $port,
    String  $jumphosts
){

    if $::operatingsystem == 'Windows' {
        include win_ultravnc::install
        include win_ultravnc::configuration
        include win_ultravnc::fw_exception
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

# Bug list
#
