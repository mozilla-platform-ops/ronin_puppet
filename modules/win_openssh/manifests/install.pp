# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::install {

    # This is being extracting into C:\programdata\ssh
    # This is not ideal, but puppet hit issues with extracting into C:\program files

    $local_program_dir = $win_openssh::ssh_program_data
    $package           = 'OpenSSH-Win64'
    $ssh_script        = "${local_program_dir}\\${package}\\install-sshd.ps1"

    win_packages::win_zip_pkg { $package:
        pkg         => 'OpenSSH-Win64.zip',
        creates     => "${local_program_dir}\\${package}\\ssh.exe",
        destination => $local_program_dir,
    }
    win_shared::execonce { 'install_openssh':
        command   => "${win_openssh::pwrshl_run_script} ${ssh_script}",
        tries     => 2,
        try_sleep => 5,
    }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1527484
