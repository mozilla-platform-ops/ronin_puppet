# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Intel Graphics Software (IntelGraphicsSoftwareService). Defaults live in
# data/os/Windows.yaml and can be overridden per worker type in
# data/os/Windows/worker/<workertype>.yaml.
class roles_profiles::profiles::intel_graphics_software {
  case $facts['os']['name'] {
    'Windows': {
      class { 'win_intel_graphics_software':
        installer_path  => lookup('windows.intel_graphics_software.installer_path'),
        service_name    => lookup('windows.intel_graphics_software.service_name'),
        fail_if_missing => lookup('windows.intel_graphics_software.fail_if_missing'),
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
