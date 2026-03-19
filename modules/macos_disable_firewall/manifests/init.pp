# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_disable_firewall (
  Boolean $enabled = true,
) {
  if $enabled {
    exec { 'disable_macos_firewall':
      command => '/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off',
      unless  => '/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | /usr/bin/grep -q "disabled"',
      path    => ['/bin', '/usr/bin', '/usr/libexec/ApplicationFirewall'],
    }
  }
}
