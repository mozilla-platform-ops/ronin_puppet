# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Intel Graphics Software - the AppUp.IntelArcSoftware MSIX that registers
# IntelGraphicsSoftwareService.
#
# Replicates production, which is NOT uniform across the hardware:
#   NUC13 (win11-64-24h2-hw)     has the service  -> ensure present
#   NUC12 (win11-64-24h2-hw-ref) does not         -> ensure absent
#
# One golden WIM serves both platforms and the bake provisions the MSIX image-wide, so the
# NUC12 pools cannot simply decline to install it - by the time puppet runs it is already
# in the image. They need an ACTIVE removal, the same shape as
# win_disable_services::enable_appxsvc actively undoing the baked AppXSvc disable.
#
# This class never downloads. The installer lives in the Entra-only 'hardwareimaging'
# account (anonymous GET -> 409); only the bake build host has an identity, so
# worker-images prepare-base-vhdx stages it to C:\bake\extras via the config's
# extras.files list.
class win_intel_graphics_software (
  Enum['present','absent'] $ensure,
  String                   $installer_path,
  String                   $service_name,
  Boolean                  $fail_if_missing,
) {
  case $facts['os']['name'] {
    'Windows': {
      $script = "${facts['custom_win_roninprogramdata']}\\install_intel_graphics_software.ps1"

      file { $script:
        content => file('win_intel_graphics_software/install_intel_graphics_software.ps1'),
      }

      $fail_arg = $fail_if_missing ? { true => ' -FailIfMissing', default => '' }

      # The idempotence guard is the mirror image of $ensure: present -> skip when the
      # service is already there; absent -> skip when it is already gone.
      $guard = $ensure ? {
        'present' => "if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }",
        default   => "if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }",
      }

      exec { 'intel_graphics_software':
        command   => "& '${script}' -Ensure '${ensure}' -InstallerPath '${installer_path}' -ServiceName '${service_name}'${fail_arg}",
        provider  => powershell,
        unless    => $guard,
        timeout   => 1800,
        logoutput => true,
        require   => File[$script],
      }
    }
    default: {
      fail("${module_name} does not support ${$facts['os']['name']}")
    }
  }
}
