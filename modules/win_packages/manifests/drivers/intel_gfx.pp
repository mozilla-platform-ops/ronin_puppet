# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Intel graphics DRIVER (no Intel Graphics Software - see below).
#
# RELOPS-2487: this class was previously commented out of every role and could not have
# worked if enabled. Three defects, all fixed here:
#   1. it staged the installer to <systemdrive>\intel\gfx.exe but executed
#      C:\Windows\Temp\gfx.exe, a path nothing ever wrote to;
#   2. its guard read $facts['custom_display_adpater'] (sic) - a fact that is defined
#      NOWHERE in this repo, so it was always undef and the guard always true;
#   3. the file resource pulled a ~750 MB installer on every run regardless of whether the
#      driver already matched. The download is now inside the guarded exec, so a node that
#      is already on the target version transfers nothing.
#
# --noExtras is deliberate and load-bearing. It skips Resources/Extras, which is where
# IntelGraphicsSoftware_<ver>_Release.exe lives. Production's NUC12 reference pool does NOT
# have IntelGraphicsSoftwareService, and this class is how the NUC12 pools get their
# driver, so it must install the driver and nothing else. The NUC13 pools get the software
# separately via win_intel_graphics_software, which runs the same installer WITHOUT that
# flag.
class win_packages::drivers::intel_gfx (
  String $version
) {
  $srcloc = lookup('windows.ext_pkg_src')

  $pkgdir  = "${facts['custom_win_systemdrive']}\\intel"
  $gfx_exe = "gfx_win_${version}.exe"
  $gfx_url = "${srcloc}/${gfx_exe}"
  $local   = "${pkgdir}\\${gfx_exe}"

  file { $pkgdir:
    ensure => directory,
  }

  # Win32_VideoController reports the full driver version (e.g. 32.0.101.7088) while the
  # installer is named for the marketing tail (101.7088), so match on the suffix.
  $installed_check = "if (@(Get-CimInstance Win32_VideoController | Where-Object { \$_.DriverVersion -like '*${version}' }).Count -gt 0) { exit 0 } else { exit 1 }"

  exec { "intel_gfx_${version}_install":
    command   => "Invoke-WebRequest -Uri '${gfx_url}' -OutFile '${local}' -UseBasicParsing; & '${local}' -s -f --noExtras; Remove-Item '${local}' -Force -ErrorAction SilentlyContinue",
    provider  => powershell,
    unless    => $installed_check,
    timeout   => 3600,
    logoutput => true,
    require   => File[$pkgdir],
  }
}
