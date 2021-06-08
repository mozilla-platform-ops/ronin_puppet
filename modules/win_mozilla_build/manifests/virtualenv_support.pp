# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::virtualenv_support {

    require win_mozilla_build::install
    require win_mozilla_build::python_3_9_5

    $source  = $win_mozilla_build::external_source
    $venv_dir = "${win_mozilla_build::install_path}\\python\\Lib\\site-packages\\virtualenv_support"

    file { $venv_dir:
        ensure => directory,
    }
    # Original source: https://pypi.python.org/packages/cp27/p/pypiwin32/pypiwin32-219-cp27-none-win32.whl#md5=a8b0c1b608c1afeb18cd38d759ee5e29
    file { "${venv_dir}\\pypiwin32-219-cp27-none-win32.whl":
        source => "${source}/pypiwin32-219-cp27-none-win32.whl",
    }
    # Original source: https://pypi.python.org/packages/cp27/p/pypiwin32/pypiwin32-219-cp27-none-win_amd64.whl#md5=d7bafcf3cce72c3ce9fdd633a262c335
    file { "${venv_dir}\\pypiwin32-219-cp27-none-win_amd64.whl":
            source => "${source}/pypiwin32-219-cp27-none-win_amd64.whl",
    }
}
