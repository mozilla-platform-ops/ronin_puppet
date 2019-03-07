# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::modifications {

    require win_mozilla_build::install
    require win_mozilla_build::hg_install

    $mozbld = $win_mozilla_build::install_path
    file { "${mozbld}\\python3\\python.exe":
        ensure => absent,
        purge  => true,
        force  => true,
    }
    file { "${mozbld}\\python\\Scripts\\hg":
        ensure => absent,
        purge  => true,
        force  => true,
    }

    file { "${win_mozilla_build::system_drive}\\home":
        ensure => link,
        target => "${win_mozilla_build::system_drive}\\users",
    }
    file { "${mozbld}\\msys\\home":
        ensure => link,
        target => "${win_mozilla_build::system_drive}\\users",
    }
    # Resource from counsyl-windows
    windows::environment { 'MOZILLABUILD':
        value => $win_mozilla_build::install_path,
    }
    # Resource from counsyl-windows
    windows::path {
        [
            "${win_mozilla_build::program_files}\\Mercurial",
            "${mozbld}\\bin",
            "${mozbld}\\kdiff",
            "${mozbld}\\moztools-x64\\bin",
            "${mozbld}\\mozmake", "${mozbld}\\nsis-3.01",
            "${mozbld}\\python",
            "${mozbld}\\python\\Scripts",
            "${mozbld}\\python3",
            "${mozbld}\\msys\\bin",
            "${mozbld}\\msys\\local\\bin"
        ]:
    }
}
