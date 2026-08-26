# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Intel Graphics Software - the AppUp.IntelArcSoftware MSIX that registers
# IntelGraphicsSoftwareService. Present on MDT production nodes, absent on nodes built
# from the pre-baked WIM, because the MU-catalog driver cab carries the DCH INF only and
# the companion MSIX normally arrives via Windows Update, which is disabled by design.
#
# Idempotent and self-selecting, so the same class works in both places:
#   bake   - service absent + installer staged locally -> installs it into the image
#   deploy - service already present from the WIM      -> no-op (just starts it if stopped)
#
# It does NOT download. The installer lives in the 'hardwareimaging' account, which is
# Entra-only (anonymous GET -> 409): the bake build host has a managed identity and can
# azcopy it in, a deployed NUC has no Azure identity and cannot. Staging it into the image
# is therefore a worker-images prepare-base-vhdx job, the same route the driver cabs take.
class win_intel_graphics_software (
  String  $installer_path,
  String  $service_name,
  Boolean $fail_if_missing,
) {
  case $facts['os']['name'] {
    'Windows': {
      $script = "${facts['custom_win_roninprogramdata']}\\install_intel_graphics_software.ps1"

      file { $script:
        content => file('win_intel_graphics_software/install_intel_graphics_software.ps1'),
      }

      $fail_arg = $fail_if_missing ? { true => ' -FailIfMissing', default => '' }

      exec { 'install_intel_graphics_software':
        command   => "& '${script}' -InstallerPath '${installer_path}' -ServiceName '${service_name}'${fail_arg}",
        provider  => powershell,
        unless    => "if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }",
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
