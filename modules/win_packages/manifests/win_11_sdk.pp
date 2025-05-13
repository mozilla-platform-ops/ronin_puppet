# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::win_11_sdk {
  $prog_dir = $facts['custom_win_programfilesx86']
  $sdk_dir   = "${prog_dir}\\Microsoft SDKs\\Windows Kits\\10\\ExtensionSDKs\\Microsoft.UniversalCRT.Debug\\10.0.26100.0"

  if $facts['os']['name'] == 'Windows' {
    # This is the win 10 SDK. poor exe naming.
    win_packages::win_exe_pkg { 'winsdksetup_5040':
      pkg                    => 'winsdksetup_5040.exe',
      install_options_string => '/q /norestart',
      creates                => "${sdk_dir}\\SDKManifest.xml",
    }
  } else {
    fail("${module_name} does not support ${$facts['os']['name']}")
  }
}
