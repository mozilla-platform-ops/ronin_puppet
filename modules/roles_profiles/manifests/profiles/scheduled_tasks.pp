# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::scheduled_tasks {

    case $::operatingsystem {
        'Windows': {
            if ($facts['custom_win_location'] == 'azure') {
                $script = 'azure-maintainsystem.ps1'
            } else {
                $script = 'maintainsystem.ps1'
            }
            class { 'win_scheduled_tasks::maintain_system':
                script => $script,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
