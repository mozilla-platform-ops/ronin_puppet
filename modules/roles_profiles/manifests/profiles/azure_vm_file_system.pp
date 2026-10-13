# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::azure_vm_file_system {
  case lookup('win-worker.function') {
    'builder', 'tester': {
      class { 'win_filesystem::configure_nvme_disk':
        work_volume => lookup('windows_work_volume', { 'default_value' => false }),
      }
    }
    default: {
      # No special file system configuration needed for this VM function.
    }
  }
}
