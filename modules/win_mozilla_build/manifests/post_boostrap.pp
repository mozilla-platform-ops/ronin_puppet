# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::post_boostrap (
    String $install_path,
    String $system_drive,
    String $cache_drive,
    String $program_files,
    String $programdata,
    String $tempdir,
    String $system32,
    String $builds_dir,
    $tooltool_tok = undef
) {

    $hg_cache = "${cache_drive}\\hg-shared"
    $mozbld   = $install_path

    exec { 'grant_symlnk_access':
        command  => file('win_mozilla_build/grant_symlnk_access.ps1'),
        provider => powershell,
    }
    file { $hg_cache:
        ensure => directory,
    }
    windows::environment { 'HG_CACHE':
        value => $hg_cache,
    }
    # Resource from puppetlabs-acl
    acl { $hg_cache:
        target      => $hg_cache,
        permissions => {
            identity                   => 'everyone',
            rights                     => ['full'],
            perm_type                  => 'allow',
            child_types                => 'all',
            affects                    => 'all',
            inherit_parent_permissions => true,
        }
    }
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
        value => $install_path,
    }
    windows_env { "PATH=${mozbld}\\bin": }
    windows_env { "PATH=${mozbld}\\kdiff": }
    windows_env { "PATH=${mozbld}\\msys2": }
    windows_env { "PATH=${mozbld}\\python3": }
    windows_env { "PATH=${mozbld}\\mozmake": }
    windows_env { "PATH=${mozbld}\\msys2\\usr\\bin": }

    exec { 'set_path':
        command  => file('win_mozilla_build/set_path.ps1.'),
        provider => powershell,
    }
    file {"${cache_drive}\\pip-cache":
        ensure => directory,
    }
    # Resource from puppetlabs-acl
    acl { "${cache_drive}\\pip-cache":
        target      => "${cache_drive}\\pip-cache",
        permissions => {
            identity                   => 'everyone',
            rights                     => ['full'],
            perm_type                  => 'allow',
            child_types                => 'all',
            affects                    => 'all',
            inherit_parent_permissions => true,
        }
    }
    # Resource from counsyl-windows
    windows::environment{ 'PIP_DOWNLOAD_CACHE':
        value => "${cache_drive}\\pip-cache",
    }
}
