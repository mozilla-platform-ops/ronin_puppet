# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_new::install {
  $mozbld_version = lookup('win-worker.mozilla_build.version')

  win_packages::win_exe_pkg { 'mozilla_build_new':
    pkg                    => "MozillaBuildSetup-${mozbld_version}.exe",
    install_options_string => '/S',
    creates                => "C:\\mozilla-build\\msys2\\usr\\bin\\sh.exe",
  }
}
