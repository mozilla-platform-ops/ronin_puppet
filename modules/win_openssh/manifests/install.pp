# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::install {

    # Becuase of the need for the script path to be double quoted, needed to hard code the path.
    $sshscrpt         = '"C:\Program Files\OpenSSH-Win64\install-sshd.ps1"'

    win_packages::win_zip_pkg { 'OpenSSH-Win64':
        pkg         => 'OpenSSH-Win64.zip',
        creates     => "${win_openssh::programfiles}\\OpenSSH-Win64\\ssh.exe",
        destination => $win_openssh::programfiles,
    }
    shared::execonce { 'install_openssh':
        command   => "${win_openssh::pwrshl_run_scrpt} ${sshscrpt}",
        tries     => 2,
        try_sleep => 5,
    }
}
