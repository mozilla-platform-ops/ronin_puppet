# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::drivers::intel_gfx (
  String $version
) {

    $gfx_driver = "gfx_win_${version}"

    win_packages::win_exe_pkg  { $gfx_driver:
        pkg                    => "${gfx_driver}.exe",
        install_options_string => '-s',
        creates                => "${facts['custom_win_programfiles']}\\intel\\Media",
    }
}
