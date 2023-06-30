# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs additional software based on whether it's a tester or builder
class roles_profiles::profiles::microsoft_tools {
  case $facts['os']['name'] {
    'Windows': {
      ## May not be needed. Start pahasing out with 2022
      if $facts['os']['release']['full'] == '2016' {
          include win_os_settings::powershell_profile
      }
      include win_shared::win_ronin_dirs
      class { 'win_packages::performance_tool_kit':
        moz_profile_source => lookup('win-worker.mozilla_profile.source'),
        moz_profile_file   => lookup('win-worker.mozilla_profile.local'),
      }

      case $facts['custom_win_purpose'] {
        'builder':{
          include win_packages::win_10_sdk
          include win_packages::dxsdk_jun10
          include win_packages::binscope
          # Required by rustc (tooltool artefact)
          include win_packages::vc_redist_x86
          include win_packages::vc_redist_x64
        }
        'tester':{
          include win_packages::win_10_sdk
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
