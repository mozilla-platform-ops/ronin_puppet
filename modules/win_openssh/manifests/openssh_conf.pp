# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_openssh::openssh_conf {

    require win_openssh::openssh_install

    $programdata = $facts['custom_win_programdata']

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

    file { "${programdata}\\ssh":
        ensure => directory,
    }
    file { "${programdata}\\ssh\\sshd_config":
        content => file('roles_profiles/windows/sshd_config'),
    }
}
