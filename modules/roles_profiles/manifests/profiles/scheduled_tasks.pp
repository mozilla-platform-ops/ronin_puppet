# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::scheduled_tasks {
  case $facts['os']['name'] {
    'Windows': {
      if ($facts['custom_win_location'] == 'azure') {
        #case $facts['custom_win_os_version'] {
        #  'win_2022_2009': {
        #    $startup_script = '2022-azure-maintainsystem.ps1'
        #  }
        #  default: {
        #    $startup_script = 'azure-maintainsystem.ps1'
        #  }
        #}
        $startup_script = 'azure-maintainsystem.ps1'
        ## Temp change for new 2012 image.
        #$startup_script = '2012-azure-maintainsystem.ps1'
        include win_scheduled_tasks::at_task_user_logon
      } else {
        $startup_script = 'maintainsystem.ps1'
      }
      class { 'win_scheduled_tasks::maintain_system':
        startup_script => $startup_script,
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
