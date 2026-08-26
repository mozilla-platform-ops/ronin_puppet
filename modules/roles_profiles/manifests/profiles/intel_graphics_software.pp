# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Intel Graphics Software (IntelGraphicsSoftwareService).
#
# $ensure is a parameter rather than a plain hiera lookup because the discriminator is the
# ROLE, and there is no role level in the Windows hiera hierarchy - win_hiera.yaml keys the
# per-worker level on custom_win_gw_workertype, which is EMPTY on these hardware pools
# (HKLM\SOFTWARE\Mozilla\ronin_puppet\workerType is unset on nuc13-115, t-nuc12-002 and
# t-nuc12-004 alike), so that level never matches. NUC13 roles take the default; NUC12
# roles declare this profile with ensure => 'absent'.
class roles_profiles::profiles::intel_graphics_software (
  Enum['present','absent'] $ensure = lookup('windows.intel_graphics_software.ensure'),
) {
  case $facts['os']['name'] {
    'Windows': {
      class { 'win_intel_graphics_software':
        ensure          => $ensure,
        installer_path  => lookup('windows.intel_graphics_software.installer_path'),
        service_name    => lookup('windows.intel_graphics_software.service_name'),
        fail_if_missing => lookup('windows.intel_graphics_software.fail_if_missing'),
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
