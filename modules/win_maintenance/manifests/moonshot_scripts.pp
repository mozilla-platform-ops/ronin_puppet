# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_maintenance::moonshot_scripts {

    $audit_dir="${facts['custom_win_roninprogramdata']}\\audit"

    file { $audit_dir:
        ensure => directory,
    }

    file { "${audit_dir}\\worker_status.ps1":
        content => file('win_maintenance/worker_status.ps1'),
    }
    file { "${audit_dir}\\force_restore.ps1":
        source => "${facts['custom_win_systemdrive']}\\ronin\\modules\\win_maintenance\\files\\trigger_restore.ps1",
        # content => file('win_maintenance/trigger_restore.ps1'),
    }
}
