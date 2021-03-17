# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::service {

    service { 'sshd':
        ensure    => running,
        subscribe => File["${win_openssh::ssh_program_data}\\sshd_config"],
        restart   => true,
        require   => Exec['install_openssh'],
    }
}
