# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_generic_worker::install {

    require win_generic_worker::directories
    require win_packages::nssm

    if ($win_generic_worker::current_gw_version != $win_generic_worker::needed_gw_version) and
        ($win_generic_worker::gw_service_status == 'present') {
        exec { 'purge_old_gw_exe':
            command  => "remove-Item –path ${win_generic_worker::generic_worker_exe}",
            provider => powershell,
        }
    }
    file { $win_generic_worker::generic_worker_exe:
        source => $win_generic_worker::generic_worker_exe_source,
    }

    if $win_generic_worker::gw_service_status != 'present' {
        exec { 'install_generic_worker_service':
            command => $win_generic_worker::generic_worker_install_command,
            require => File[$win_generic_worker::generic_worker_exe],
        }
    }
    exec { 'generate_ed25519_keypair':
        command =>
            "${win_generic_worker::generic_worker_exe} new-ed25519-keypair --file ${win_generic_worker::ed25519signingkey}",
        require => File[$win_generic_worker::generic_worker_exe],
        creates => $win_generic_worker::ed25519signingkey,
    }
}
