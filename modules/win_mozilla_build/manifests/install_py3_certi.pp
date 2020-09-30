# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::install_py3_certi {

    require win_mozilla_build::install

    $mozbld = $win_mozilla_build::install_path

    exec { 'install_py3_certi':
        command => "${mozbld}\\python3\\python3.exe -m pip install certifi",
        creates => "${mozbld}\\python3\\Lib\\site-packages\\certifi\cacert.pem",
    }
}

# This insatllation ensures that Python3 has the proper cacert.pem file
# see https://bugzilla.mozilla.org/show_bug.cgi?id=1662170
