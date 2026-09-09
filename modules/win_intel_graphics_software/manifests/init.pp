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
# account (anonymous GET -> 409) and a deployed NUC has no Azure identity, so worker-images
# prepare-base-vhdx stages it INTO THE GOLDEN WIM at C:\extras via the config's
# extras.files list, and this class runs it here, at deploy time, on real hardware.
#
# Deploy time and not bake time on purpose: Intel's installer returns rc=1008 in the
# GPU-less Hyper-V build guest, and the MSIX is a per-user install that sysprep /generalize
# strips from the image. So win116424h2hwbake does NOT include this profile.
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

      # Marker consumed by maintainsystem-hw.ps1. Its content is the installer path, so hiera
      # stays the single source of truth for it.
      $marker = "${facts['custom_win_roninprogramdata']}\\install_intel_graphics_software.deferred"

      if $ensure == 'present' {
        # DEFERRED ON PURPOSE. Intel's installer takes ~3 min (measured 2m46s-3m03s on
        # nuc13-074/115/158), which roughly doubled the deploy's ~2.5-3 min puppet phase. Running
        # it here blocks the node from reporting ready for no reason - nothing else needs the
        # service. The first maintainsystem run after deploy installs it instead. RELOPS-2487.
        file { $marker:
          ensure  => file,
          content => $installer_path,
          require => File[$script],
        }
      } else {
        file { $marker:
          ensure => absent,
        }

        # Removal is NOT deferred: it is a fast no-op on a node that never had the service, and a
        # NUC12 pool must never be left carrying it even briefly. Guard is the mirror of $ensure -
        # skip when it is already gone.
        exec { 'intel_graphics_software':
          command   => "& '${script}' -Ensure '${ensure}' -InstallerPath '${installer_path}' -ServiceName '${service_name}'${fail_arg}",
          provider  => powershell,
          unless    => "if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }",
          timeout   => 1800,
          logoutput => true,
          require   => File[$script],
        }
      }
    }
    default: {
      fail("${module_name} does not support ${$facts['os']['name']}")
    }
  }
}
