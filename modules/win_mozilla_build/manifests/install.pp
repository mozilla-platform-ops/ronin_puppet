# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::install {

    if $win_mozilla_build::current_version != $win_mozilla_build::version {
        win_packages::win_exe_pkg  { 'mozilla_build':
            pkg                    => "MozillaBuildSetup-${win_mozilla_build::version}.exe",
            install_options_string =>  "/S /D=${win_mozilla_build::install_path}",
            creates                => "${win_mozilla_build::install_path}\\msys\\bin\\sh.exe"
        }
    }
}
