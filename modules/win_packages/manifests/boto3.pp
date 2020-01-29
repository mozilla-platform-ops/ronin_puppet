# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::boto3 {

    require win_mozilla_build::pip

    exec { 'boto3':
        command => "${facts['custom_win_systemdrive']}\\mozilla-build\\python3\\python3.exe -m pip install boto3",
    }
}
