# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::openssh_service {

    require win_openssh::openssh_install

    $programdata = $facts['custom_win_programdata']

    service { 'sshd':
        ensure    => running,
        subscribe => File["${programdata}\\ssh\\sshd_config"],
        restart   => true,
        require   => Exec['install_openssh'],
    }
}
