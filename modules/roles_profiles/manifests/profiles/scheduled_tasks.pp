# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::scheduled_tasks {

    case $::operatingsystem {
        'Windows': {
            if ($facts['custom_win_location'] == 'azure') {
                $startup_script = 'azure-maintainsystem.ps1'
                include win_scheduled_tasks::at_task_user_logon
                include win_scheduled_tasks::kill_remote_clipboard
            } else {
                $startup_script = 'maintainsystem.ps1'
            }
            class { 'win_scheduled_tasks::maintain_system':
                startup_script => $startup_script,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
