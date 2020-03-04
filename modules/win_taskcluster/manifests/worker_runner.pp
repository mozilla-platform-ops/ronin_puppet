# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::worker_runner (
    String $worker_runner_dir,
    String $desired_runner_version,
    String $current_runner_version,
    String $runner_exe_source,
) {

    require win_packages::nssm

    $runner_exe_path = "${worker_runner_dir}\\start-worker.exe"

    if ($current_runner_version != $desired_runner_version) {
        exec { 'purge_old_gw_exe':
            command  => "remove-Item –path ${runner_exe_path}",
            unless   => "Test-Path ${runner_exe_path}",
            provider => powershell,
        }
    }
    file { $worker_runner_dir:
        ensure => directory,
    }
    file { $runner_exe_path:
        source  => $runner_exe_source,
    }
}
