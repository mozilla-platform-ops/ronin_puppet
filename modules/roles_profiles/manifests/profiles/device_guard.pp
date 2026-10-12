# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Virtualization-Based Security posture. Defaults live in data/os/Windows.yaml and can
# be overridden per worker type in data/os/Windows/worker/<workertype>.yaml.
class roles_profiles::profiles::device_guard {
  case $facts['os']['name'] {
    'Windows': {
      class { 'win_device_guard':
        vbs_enabled  => lookup('windows.device_guard.vbs_enabled'),
        hvci_enabled => lookup('windows.device_guard.hvci_enabled'),
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
