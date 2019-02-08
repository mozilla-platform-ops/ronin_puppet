# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::openssh {

    case $::operatingsystem {
        'Windows': {
        $programfiles = $facts['programfiles']
        $systemdrive  = $facts['systemdrive']
        $programdata  = $facts['programdata']

            defined_classes::pkg::win_zip_pkg { 'OpenSSH-Win64':
                pkg         => 'OpenSSH-Win64.zip',
                creates     => "${programfiles}\\OpenSSH-Win64\\ssh.exe",
                destination => $programfiles,
            }
            defined_classes::exec::execonce { 'install_openssh':
                command  => "${programfiles}\\OpenSSH-Win64\\install-sshd.ps1",
                provider => powershell,
            }
            registry_value { 'HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH\DefaultShell':
                ensure => present,
                type   => string,
                data   => 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
            }
            registry_key { 'HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH':
                ensure => present,
            }
            registry_value { 'HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH\DefaultShellCommandOption':
                ensure => present,
                type   => string,
                data   => '/c',
            }
            file { "${systemdrive}\\Users\\administrator\\.ssh":
                ensure => directory,
            }
            file { "${programdata}\\ssh":
                        ensure => directory,
            }
            file { "${systemdrive}\\Users\\administrator\\.ssh\\authorized_keys":
                content => file('roles_profiles/windows/authorized_keys'),
            }
            file { "${programdata}\\ssh\\sshd_config":
                content => file('roles_profiles/windows/sshd_config'),
            }
            service { 'sshd':
                ensure    => running,
                subscribe => File["${programdata}\\ssh\\sshd_config"],
                restart   => true,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524440
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
