# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::scheduled_tasks {
  include win_scheduled_tasks::at_task_user_logon
  case $facts['os']['name'] {
    'Windows': {
      case $facts['custom_win_location'] {
        'azure': {
          if $facts['custom_win_os_version'] == '2012' {
            $startup_script = '2012-azure-maintainsystem.ps1'
          } else {
            $startup_script = 'azure-maintainsystem.ps1'
          }
          include win_scheduled_tasks::at_task_user_logon
        }
        'datacenter': {
          $startup_script = 'maintainsystem-reftester.ps1'
        }
        default: {
          $startup_script = 'maintainsystem.ps1'
        }
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
