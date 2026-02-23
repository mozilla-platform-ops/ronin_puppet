# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::wifi_disabled {
  if $facts['os']['name'] == 'Darwin' {
    $wifi_interface = $::networking['interfaces']['en1'] ? {
      undef   => 'en0',
      default => 'en1',
    }

    exec { 'disable-wifi':
      command     => "/usr/sbin/networksetup -setairportpower ${wifi_interface} off",
      unless      => "/usr/sbin/networksetup -getairportpower ${wifi_interface} | grep 'Off'",
      refreshonly => false,
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
