# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_storage_sense {
  # Disable Storage Sense entirely at the system level
  # When disabled, Storage Sense is turned off for the machine and users can't enable it
  registry_value { 'HKLM/SOFTWARE/Policies/Microsoft/Windows/StorageSense/AllowStorageSenseGlobal':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  # Disable Storage Sense temporary files cleanup
  # When disabled, Storage Sense won't delete temporary files and users can't enable this setting
  registry_value { 'HKLM/SOFTWARE/Policies/Microsoft/Windows/StorageSense/AllowStorageSenseTemporaryFilesCleanup':
    ensure => present,
    type   => dword,
    data   => '0',
  }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1893092
