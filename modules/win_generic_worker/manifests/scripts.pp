# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_generic_worker::scripts {

    $gw_dir = $win_generic_worker::generic_worker_dir

    require win_generic_worker::directories
    require win_generic_worker::install

    # This will changed based on OS
    file { $win_generic_worker::task_user_init_cmd:
        content   => file('win_generic_worker/task-user-init-win10.cmd'),
    }
    file { $win_generic_worker::disable_desktop_interrupt:
        content   => file('win_generic_worker/disable-desktop-interrupt.reg'),
    }
    file { $win_generic_worker::set_default_printer:
        content   => file('win_generic_worker/set_default_printer.ps1'),
    }
    # This will change based on location
    file { "${gw_dir}\\run-generic-worker.bat":
        content   => epp('win_generic_worker/run-hw-generic-worker-and-reboot.bat.epp'),
    }
}
