# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gpu_drivers {
  ## Use https://docs.nvidia.com/grid/index.html & https://github.com/Azure/azhpc-extensions/blob/master/NvidiaGPU/resources.json as reference
  case $facts['os']['name'] {
    'windows': {
      class { 'win_packages::drivers::nvidia_grid':
        display_name => lookup('windows.gpu.display_name'),
        driver_name  => lookup('windows.gpu.name'),
        srcloc       => lookup('windows.ext_pkg_src'),
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
