# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service (
  String $source_location
) {
  $source_exe      = "${source_location}/maintenanceservice.exe"
  $maintenance_key = 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Mozilla\\MaintenanceService\\3932ecacee736d366d6436db0f55bce4'

  case $facts['os']['name'] {
    'Windows': {
      include win_mozilla_maintenance_service::install
      include win_mozilla_maintenance_service::grant_registry_access
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
