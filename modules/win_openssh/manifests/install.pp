# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::install {

    # Becuase of the need for the script path to be double quoted, needed to hard code the path.
    $ssh_script        = "\"${win_openssh::programfiles}\\install-sshd.ps1\""
    $local_program_dir = "\"${win_openssh::programfiles}\\\""

    win_packages::win_zip_pkg { 'OpenSSH-Win64':
        pkg         => 'OpenSSH-Win64.zip',
        creates     => "${win_openssh::programfiles}\\OpenSSH-Win64\\ssh.exe",
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
# The powershell command fails on 1st run but is OK on the second run
