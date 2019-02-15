# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::virtualenv_support {

    require win_mozilla_build::install

    $venv_dir = "${win_mozilla_build::install_path}\\python\\Lib\\site-packages\\virtualenv_support"

    file { $venv_dir:
        ensure => directory,
    }

    file { "${venv_dir}\\pypiwin32-219-cp27-none-win32.whl":
        content => file('win_mozilla_build/pypiwin32-219-cp27-none-win32.whl'),
    }
    file { "${venv_dir}\\pypiwin32-219-cp27-none-win_amd64.whl":
        content => file('win_mozilla_build/pypiwin32-219-cp27-none-win_amd64.whl'),
    }

}
