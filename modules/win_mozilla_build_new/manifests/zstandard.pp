# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_new::install_zstandard {
  $zstandard_version = lookup('win-worker.mozilla_build.zstandard_version')
  $pip_string  = "-m pip install zstandard==${zstandard_version}"
  $create_path = 'Lib\\site-packages\\zstandard\\__init__.py'

  exec { 'install_zstandard':
    command => "C:\\mozilla-build\\python3\\python3.exe ${pip_string}",
    creates => "C:\\mozilla-build\\python3\\${create_path}",
  }
}
