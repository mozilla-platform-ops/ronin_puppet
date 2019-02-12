# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::openssh_install {

    $programfiles     = $facts['custom_win_programfiles']
    $pwrshl_run_scrpt = lookup('pwrshl_run_scrpt')
    # Becuase of the need for the script path to be double quoted, needed to hard code the path.
    $sshscrpt         = '"C:\Program Files\OpenSSH-Win64\install-sshd.ps1"'

    win_packages::win_zip_pkg { 'OpenSSH-Win64':
        pkg         => 'OpenSSH-Win64.zip',
        creates     => "${programfiles}\\OpenSSH-Win64\\ssh.exe",
        destination => $programfiles,
    }
    shared::execonce { 'install_openssh':
        command  => "${pwrshl_run_scrpt} ${sshscrpt}",
    }
}
