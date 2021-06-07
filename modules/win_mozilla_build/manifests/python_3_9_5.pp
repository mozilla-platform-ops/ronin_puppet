# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::python_3_9_5 {


    exec { 'remove_old_pyhton3':
        command  => "Remove-Item -Recurse -Force ${win_mozilla_build::install_path}\\python3",
        unless   => "test-path ${win_mozilla_build::install_path}\\python3\\python39.dll",
        provider => powershell,
    }


    win_packages::win_exe_pkg  { 'python_3_9_5':
        pkg                    => 'python-3.9.5-amd64.exe',
        install_options_string => 'TargetDir=C:\mozilla-build\pyhton3 /passive',
        creates                => "${win_mozilla_build::install_path}\\python3\\python39.dll",
    }
}
