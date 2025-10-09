# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::minimize_cmd {
  $minimize_cmd = "${facts['custom_win_roninprogramdata']}\\minimize_cmd.ps1"
  file { $minimize_cmd:
    content => file('win_scheduled_tasks/minimize_cmd.ps1'),
  }
}
