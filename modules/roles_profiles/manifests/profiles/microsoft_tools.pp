# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::microsoft_tools {
  case $facts['os']['name'] {
    'Windows': {
      include win_os_settings::powershell_profile
      class { 'win_packages::performance_tool_kit':
        moz_profile_source => lookup('win-worker.mozilla_profile.source'),
        moz_profile_file   => lookup('win-worker.mozilla_profile.local'),
      }

      case $facts['custom_win_os_version'] {
        'win_10_2004': {
          $purpose = 'tester'
        }
        'win_11_2009': {
          $purpose = 'tester'
        }
        'win_2012': {
          $purpose = 'builder'
        }
        'win_2022_2009': {
          $purpose = 'builder'
        }
        default: {
          fail("${$facts['os']['name']} not supported")
        }
      }

      case $purpose {
        'builder': {
          case $facts['custom_win_os_version'] {
            'win_2022_2009': {
              include win_packages::vs_buildtools_2022
            }
            'win_2012':{
              include win_packages::vs_buildtools
              include win_packages::dxsdk_jun10
              include win_packages::binscope
              # Required by rustc (tooltool artefact)
              include win_packages::vc_redist_x86
              include win_packages::vc_redist_x64
            }
            default: {
              include win_packages::vs_buildtools
              include win_packages::dxsdk_jun10
              include win_packages::binscope
              # Required by rustc (tooltool artefact)
              include win_packages::vc_redist_x86
              include win_packages::vc_redist_x64
            }
          }
        }
        'tester': {
          case $facts['custom_win_os_version'] {
            'win_11_2009': {
              include win_packages::vs_buildtools_2022
            }
            'win_10_2004': {
              include win_packages::vs_buildtools
            }
            default: {
              include win_packages::vs_buildtools
            }
          }
        }
        default: {
          include win_packages::vs_buildtools
        }
      }
      # Bug List
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1510837
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
