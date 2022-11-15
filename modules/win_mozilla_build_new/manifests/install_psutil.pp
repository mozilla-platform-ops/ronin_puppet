# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs psutil python package within mozbuild
class win_mozilla_build_new::install_psutil {
  $psutil_version = lookup('win-worker.mozilla_build.psutil_version')
  $pip_string  = "-m pip install psutil==${psutil_version}"
  $create_path = 'Lib\\site-packages\\psutil\\__init__.py'

  exec { 'install_py3_psutil':
    command => "C:\\mozilla-build\\python3\\python3.exe ${pip_string}",
    creates => "C:\\mozilla-build\\python3\\${create_path}",
  }
}
