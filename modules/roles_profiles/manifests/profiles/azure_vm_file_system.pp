# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::azure_vm_file_system {
  if facts['custom_win_vmSize'] == 'Standard_D32alds_v6' {
    include win_filesystem::configure_nvme_disk
  }
}
