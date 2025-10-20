# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::task_user_background_script {
  $task_user_background_script = "${facts['custom_win_roninprogramdata']}\\task_user_background_script.ps1"
  file { $task_user_background_script:
    content => file('win_scheduled_tasks/task_user_background_script.ps1'),
  }
}
