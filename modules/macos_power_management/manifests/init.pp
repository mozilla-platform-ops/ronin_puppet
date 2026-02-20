# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_power_management {
  exec { 'pmset_sleep':
    command => '/usr/bin/pmset -a sleep 0',
    unless  => '/usr/bin/pmset -g | /usr/bin/grep -w sleep | /usr/bin/grep -w 0',
  }

  exec { 'pmset_displaysleep':
    command => '/usr/bin/pmset -a displaysleep 0',
    unless  => '/usr/bin/pmset -g | /usr/bin/grep -w displaysleep | /usr/bin/grep -w 0',
  }

  exec { 'pmset_disksleep':
    command => '/usr/bin/pmset -a disksleep 0',
    unless  => '/usr/bin/pmset -g | /usr/bin/grep -w disksleep | /usr/bin/grep -w 0',
  }

  exec { 'pmset_womp':
    command => '/usr/bin/pmset -a womp 1',
    unless  => '/usr/bin/pmset -g | /usr/bin/grep -w womp | /usr/bin/grep -w 1',
  }

  exec { 'pmset_autorestart':
    command => '/usr/bin/pmset -a autorestart 1',
    unless  => '/usr/bin/pmset -g | /usr/bin/grep -w autorestart | /usr/bin/grep -w 1',
  }

  exec { 'pmset_SleepDisabled':
    command => '/usr/bin/pmset -a SleepDisabled 1',
    unless  => '/usr/bin/pmset -g | /usr/bin/grep -w SleepDisabled | /usr/bin/grep -w 1',
  }
}
