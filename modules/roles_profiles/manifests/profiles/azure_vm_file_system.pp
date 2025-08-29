# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::azure_vm_file_system {
  $vm_size_fact = facts.dig('custom_win_vmSize')

  if $vm_size_fact {
    case String($vm_size_fact) {
      'Standard_D32alds_v6': {
        include win_filesystem::configure_nvme_disk
      }
      default: {
        # No special file system configuration needed for this VM size
      }
    }
  }
}
