# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::set_registry_priority {

    require win_mozilla_build::install
    require win_mozilla_build::hg_install

    $py_key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\python.exe\PerfOptions'
    $hg_key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\hg.exe\PerfOptions'

    # Resources from puppetlabs-registry
    registry_key { $py_key:
        ensure => present,
    }
    registry_value { "${py_key}\\CpuPriorityClass":
        ensure => present,
        type   => dword,
        data   => '0x00000006',
    }
    registry_value { "${py_key}\\IoPriority":
        ensure => present,
        type   => dword,
        data   => '0x00000002',
    }

    registry_key { $hg_key:
        ensure => present,
    }
    registry_value { "${hg_key}\\CpuPriorityClass":
        ensure => present,
        type   => dword,
        data   => '0x00000006',
    }
    registry_value { "${hg_key}\\IoPriority":
        ensure => present,
        type   => dword,
        data   => '0x00000002',
    }
}
