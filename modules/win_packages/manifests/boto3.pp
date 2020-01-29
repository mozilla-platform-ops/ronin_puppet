# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::boto3 {

    require win_mozilla_build::pip

    $python3_path = "${facts['custom_win_systemdrive']}\\mozilla-build\\python3"

    exec { 'boto3':
        command => "${$python3_path}\\python3.exe -m pip install boto3",
        creates => "${python3_path}\\Lib\\site-packages\\boto3\\__init__.py",
    }
}
