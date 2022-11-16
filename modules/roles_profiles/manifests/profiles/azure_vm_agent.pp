# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::azure_vm_agent {
  case $facts['os']['name'] {
    'Windows': {
      $agent_version = lookup('win-worker.azure.vm_agent.version')
      $package       = lookup('win-worker.azure.vm_agent.display_name')
      $msi           = "WindowsAzureVmAgent.${agent_version}.msi"

      class { 'win_packages::azure_vm_agent':
        package => $package,
        msi     => $msi,
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
