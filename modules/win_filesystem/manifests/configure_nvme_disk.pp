# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::configure_nvme_disk {
  # https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-temp-faqs
  exec { 'configure_nvme_disk':
    command     => file('win_filesystem/configure_nvme_disk.ps1'),
    provider    => powershell,
    refreshonly => true,
  }
}
