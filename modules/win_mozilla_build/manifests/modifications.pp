# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::modifications {

    require win_mozilla_build::install
    require win_mozilla_build::hg_install

    $mozbld = $win_mozilla_build::install_path

    file { $win_mozilla_build::builds_dir:
        ensure => directory,
    }
    if $win_mozilla_build::upgrade_python != true {
        file { "${mozbld}\\python3\\python.exe":
            ensure => absent,
            purge  => true,
            force  => true,
        }
    }
    file { "${mozbld}\\python\\Scripts\\hg":
        ensure => absent,
        purge  => true,
        force  => true,
    }
    # File resource fails when create symlink
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1544140
    # Commenting out to be restored at a later time
    # May not be needed for testers
    #file { "${win_mozilla_build::system_drive}\\home":
    #    ensure => link,
    #    target => "${win_mozilla_build::system_drive}\\users",
    #}
    #file { "${mozbld}\\msys\\home":
    #    ensure => link,
    #    target => "${win_mozilla_build::system_drive}\\users",
    #}
    # Resource from counsyl-windows
    windows::environment { 'MOZILLABUILD':
        value => $win_mozilla_build::install_path,
    }
    # Resource from counsyl-windows
    if $win_mozilla_build::upgrade_python == true {
        windows_env { "PATH=${win_mozilla_build::program_files}\\Mercurial": }
        windows_env { "PATH=${mozbld}\\bin": }
        windows_env { "PATH=${mozbld}\\kdiff": }
        windows_env { "PATH=${mozbld}\\moztools-x64\\bin": }
        windows_env { "PATH=${mozbld}\\mozmake": }
        windows_env { "PATH=${mozbld}\\nsis-3.01": }
        windows_env { "PATH=${mozbld}\\python": }
        windows_env { "PATH=${mozbld}\\python\\Scripts": }
        windows_env { "PATH=${mozbld}\\python3": }
        windows_env { "PATH=${mozbld}\\msys\\bin": }
        windows_env { "PATH=${mozbld}\\msys\\bin": }
        windows_env { "PATH=${mozbld}\\msys\\local\\bin": }
    } else {
      # Deprecate use of windows::path during 2022 hardware refreshes
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
}
