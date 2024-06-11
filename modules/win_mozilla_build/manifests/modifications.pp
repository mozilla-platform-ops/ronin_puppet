# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::modifications {

    require win_mozilla_build::install
    require win_mozilla_build::hg_install

    $mozbld      = $win_mozilla_build::install_path
    $source      = $win_mozilla_build::external_source
    $mozmake_dir = "${mozbld}\\mozmake"
    $pyp_string  = '-m pip install --upgrade pypiwin32==219'

    file { $mozmake_dir:
        ensure => directory,
    }
    file { "${mozmake_dir}\\mozmake.exe":
        source => "${source}/mozmake.exe",
    }


    file { $win_mozilla_build::builds_dir:
        ensure => directory,
    }
    if $win_mozilla_build::needed_mozbld_ver == '3.2' {
        if $win_mozilla_build::upgrade_python != true {
            file { "${mozbld}\\python3\\python.exe":
                ensure => absent,
                purge  => true,
                force  => true,
            }
            # For NSS builds
            # They still use Python 2
            if $facts['os']['release']['full'] == '2012 R2' {
                exec { 'install_pypiwin32':
                    command => "${mozbld}\\python\\python.exe ${pyp_string}",
                    creates => "${mozbld}\\python\\Lib\\site-packages\\pypiwin32",
                }
                file { "${facts['custom_win_system32']}\\drivers\\etc\\hosts":
                    content => file('win_mozilla_build/hosts'),
                }
            }
        }
    }
    file { "${mozbld}\\python\\Scripts\\hg":
        ensure => absent,
        purge  => true,
        force  => true,
        }
    file { "${mozbld}\\python\\Scripts\\hg.exe":
        ensure => absent,
        purge  => true,
        force  => true,
    }
    # File resource fails when create symlink
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1544140
    # Commenting out to be restored at a later time
    # May not be needed for testers
    if $facts['os']['release']['full'] == '2012 R2' {
        file { "${win_mozilla_build::system_drive}\\home":
            ensure => link,
            target => "${win_mozilla_build::system_drive}\\users",
        }
    }
    # Some builds look for old mozilla-build dirs
    # Should address thing 2022 migration
    file { "${mozbld}\\msys":
        ensure => link,
        target => "${mozbld}\\msys2",
    }
    file { "${mozbld}\\python":
        ensure => link,
        target => "${mozbld}\\python3",
    }

    # Resource from counsyl-windows
    windows::environment { 'MOZILLABUILD':
        value => $win_mozilla_build::install_path,
    }
    # Resource from counsyl-windows

    if $win_mozilla_build::needed_mozbld_ver == '4.0.1' {
        windows_env { "PATH=${mozbld}\\bin": }
        windows_env { "PATH=${mozbld}\\kdiff": }
        windows_env { "PATH=${mozbld}\\msys2": }
        windows_env { "PATH=${mozbld}\\python3": }
        windows_env { "PATH=${mozbld}\\mozmake": }
        windows_env { "PATH=${mozbld}\\msys2\\usr\\bin": }
    } elsif $win_mozilla_build::upgrade_python == true {
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
    # don't run on older mozilla build pkg
    if $win_mozilla_build::needed_mozbld_ver != '3.2' {
        exec { 'set_path':
            command  => file('win_mozilla_build/set_path.ps1.'),
            provider => powershell,
        }
    }
}
