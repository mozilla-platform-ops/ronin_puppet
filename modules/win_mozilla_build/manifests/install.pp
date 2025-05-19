# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## CLEAN UP: lookups should be in the profile and passed to this class.

class win_mozilla_build::install {
  $mozbld_version = lookup('windows.mozilla_build.version')

  win_packages::win_exe_pkg { 'mozilla_build':
    pkg                    => "MozillaBuildSetup-${mozbld_version}.exe",
    install_options_string => '/S',
    creates                => "C:\\mozilla-build\\msys2\\usr\\bin\\sh.exe",
  }
}
