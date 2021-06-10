# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::python_3_9_5 {

    require win_mozilla_build::install

    $install_dir = "${facts['custom_win_systemdrive']}\\mozilla-build\\python3"

    exec { 'remove_old_pyhton3':
        command  => "Remove-Item -Recurse -Force ${install_dir}",
        creates  => "${install_dir}\\python39.dll",
        provider => powershell,
    }


    win_packages::win_exe_pkg  { 'python_3_9_5':
        pkg                    => 'python-3.9.5-amd64.exe',
        install_options_string => "TargetDir=${install_dir} /passive",
        creates                => "${install_dir}\\python39.dll",
    }
    file { "${install_dir}\\python3.exe":
        ensure => present,
        source => "${install_dir}\\python.exe",
    }
}
