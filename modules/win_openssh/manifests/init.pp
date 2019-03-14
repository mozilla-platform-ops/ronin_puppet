# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh (
    String $ssh_program_data,
    String $programfiles,
    String $pwrshl_run_script,
    Integer $port,
    String $jumphosts
){

    if $::operatingsystem == 'Windows' {
        include win_openssh::install
        include win_openssh::configuration
        include win_openssh::fw_exception
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
