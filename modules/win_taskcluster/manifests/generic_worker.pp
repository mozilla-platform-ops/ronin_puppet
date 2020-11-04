# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::generic_worker (
    String $generic_worker_dir,
    String $desired_gw_version,
    String $current_gw_version,
    String $gw_exe_source,
    String $gw_exe_path
) {

    $ed25519private = "${generic_worker_dir}\\ed25519-private.key"

    if ($current_gw_version != $desired_gw_version) {
        exec { 'purge_old_nonservice_gw_exe':
            command  => "Remove-Item -path ${gw_exe_path}",
            unless   => "Test-Path ${gw_exe_path}",
            provider => powershell,
        }
    }
    file { $generic_worker_dir:
        ensure => directory,
    }
    file { $gw_exe_path:
        source  => $gw_exe_source,
    }
    exec { 'generate_ed25519_keypair':
        command => "${gw_exe_path} new-ed25519-keypair --file ${ed25519private}",
        creates => $ed25519private,
    }
}
