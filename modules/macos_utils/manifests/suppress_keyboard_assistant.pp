# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::suppress_keyboard_assistant {
  $launchagent_path = '/Users/cltbld/Library/LaunchAgents/com.mozilla.suppress-keyboard-assistant.plist'

  if Integer($facts['os']['release']['major']) <= 20 {
    $cltbld_uid = '36'
  } else {
    $cltbld_uid = '555'
  }

  file { $launchagent_path:
    ensure  => file,
    owner   => 'cltbld',
    group   => 'staff',
    mode    => '0644',
    source  => 'puppet:///modules/macos_utils/com.mozilla.suppress-keyboard-assistant.plist',
    require => File['/Users/cltbld/Library/LaunchAgents'],
  }

  exec { 'load or restart suppress keyboard assistant agent':
    command     => "/bin/bash -c 'if /bin/launchctl print gui/${cltbld_uid}/com.mozilla.suppress-keyboard-assistant 2>/dev/null; then \
                  /bin/launchctl kickstart -k gui/${cltbld_uid}/com.mozilla.suppress-keyboard-assistant; \
                else \
                  /bin/launchctl bootstrap gui/${cltbld_uid} \"${launchagent_path}\" 2>/dev/null; \
                fi; exit 0'",
    path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
    refreshonly => true,
    subscribe   => File[$launchagent_path],
  }
}
