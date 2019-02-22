# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::configuration {

    require win_openssh::install

    registry_key { 'HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH':
        ensure  => present,
    }
    registry_value { 'HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH\DefaultShell':
        ensure => present,
        type   => string,
        data   => 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
    }
    registry_value { 'HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH\DefaultShellCommandOption':
        ensure => present,
        type   => string,
        data   => '/c',
    }
    file { $win_openssh::ssh_program_data:
        ensure => directory,
    }
    file { "${win_openssh::ssh_program_data}\\sshd_config":
        content => file('win_openssh/sshd_config'),
    }
}
