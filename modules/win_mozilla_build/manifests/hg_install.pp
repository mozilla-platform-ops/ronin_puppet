# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::hg_install {

    if $win_mozilla_build::current_hg_ver != $win_mozilla_build::needed_hg_ver {
        win_packages::win_msi_pkg { "Mercurial ${win_mozilla_build::needed_hg_ver} (x64)" :
            pkg             => 'mercurial-4.7.1-x64.msi',
            install_options => ['/quiet'],
        }
    }
}
