# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Virtualization-Based Security (VBS) and Hypervisor-Enforced Code Integrity (HVCI).
#
# RELOPS-2487: the MDT-built production image ships with VBS running (Credential Guard
# + HVCI), but a node deployed from the pre-baked golden WIM came up with VBS entirely
# off. HVCI runs the kernel under a hypervisor and taxes syscalls, memory management
# and I/O, so the two populations were not measuring the same machine - baked nodes
# looked faster than the fleet they are meant to represent.
#
# Measured delta between a production node (nuc13-006) and a baked node (nuc13-115) was
# exactly the two registry values below. Everything else already matched: Credential
# Guard needs no key of its own (it is default-on for Windows 11 Enterprise once VBS is
# up - production shows SecurityServicesRunning 1,2 with no CredentialGuard scenario key
# and LsaCfgFlags unset), and NO Hyper-V optional feature is required (production has
# every Microsoft-Hyper-V-* feature Disabled yet reports HypervisorPresent=True, because
# Windows loads the hypervisor for VBS on its own).
#
# Takes effect on the next boot. On a deploy that is free: bootstrap already reboots
# after the puppet run. In the bake VM the values are written but VBS will not activate
# (nested virtualisation is not exposed to the packer guest) - that is fine and expected,
# the WIM carries the setting and it activates on real hardware at first boot.
class win_device_guard (
  Boolean $vbs_enabled,
  Boolean $hvci_enabled,
) {
  case $facts['os']['name'] {
    'Windows': {
      $dg_key   = 'HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard'
      $hvci_key = "${dg_key}\\Scenarios\\HypervisorEnforcedCodeIntegrity"

      $vbs_data  = $vbs_enabled ? { true => '1', default => '0' }
      $hvci_data = $hvci_enabled ? { true => '1', default => '0' }

      registry_key { $dg_key:
        ensure => present,
      }

      # Master switch. 1 = load the secure kernel at boot.
      registry_value { "${dg_key}\\EnableVirtualizationBasedSecurity":
        ensure  => present,
        type    => dword,
        data    => $vbs_data,
        require => Registry_key[$dg_key],
      }

      registry_key { $hvci_key:
        ensure  => present,
        require => Registry_key[$dg_key],
      }

      # Memory Integrity. Production reports WasEnabledBy=1 alongside this.
      registry_value { "${hvci_key}\\Enabled":
        ensure  => present,
        type    => dword,
        data    => $hvci_data,
        require => Registry_key[$hvci_key],
      }
    }
    default: {
      fail("${module_name} does not support ${$facts['os']['name']}")
    }
  }
}
