# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::azure_vm_file_system {
  $func = lookup('win-worker.function')
  case $func {
    'builder':{
      include win_filesystem::configure_nvme_disk
    }
    'tester':{
      include win_filesystem::configure_nvme_disk
    }
    default: {
      # No special file system configuration needed for this VM size
    }
  }
}
