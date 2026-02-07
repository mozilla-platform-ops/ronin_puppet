# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_maintenance::fleetroll_mvp_collect (
    String $script_dir
) {

    require win_maintenance::maintenance_script_dir

    file { "${script_dir}\\force_pxe_install.ps1":
        content => file('win_maintenance/fleetroll_mvp_collect.ps1'),
    }
}
