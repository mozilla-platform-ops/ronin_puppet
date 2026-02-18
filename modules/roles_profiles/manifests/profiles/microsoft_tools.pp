# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs additional software based on whether it's a tester or builder
class roles_profiles::profiles::microsoft_tools {
  case $facts['os']['name'] {
    'Windows': {
      include win_shared::win_ronin_dirs
      class { 'win_packages::performance_tool_kit':
        moz_profile_source => lookup('windows.mozilla_profile.source'),
        moz_profile_file   => lookup('windows.mozilla_profile.local'),
      }

      $func = lookup('win-worker.function')

      case $func {
        'builder':{
          ## This class seems to timeout on the first run of a new VM
          ## For now don't look for it after bootstrap.
          if $facts['custom_win_bootstrap_stage'] != 'complete' {
            include win_packages::dxsdk_jun10
          }
          include win_packages::binscope
          # Required by rustc (tooltool artefact)
          if $facts['custom_win_os_arch'] == 'aarch64' {
            include win_packages::vc_redist_x86
            include win_packages::vc_redist_x64
          }
          else {
            include win_packages::vc_redist_2022_x64
            include win_packages::vc_redist_2022_x86
          }
        }
        'tester':{
          # Hardware testers don't need the windows sdk so skip installing them completely
          if $facts['custom_win_location'] == 'azure' and $facts['custom_win_os_arch'] != 'aarch64' {
            if $facts['custom_win_display_version'] == '24H2' {
              include win_packages::win_11_sdk
            } else {
              ## we still install win10 sdk on win11-64-2009
              include win_packages::win_10_sdk
            }
          }
          include win_hw_profiling::xperf_kernel_trace
        }
        default: {
          fail("${$facts['custom_win_purpose']} not supported")
        }
      }
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1510837
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
