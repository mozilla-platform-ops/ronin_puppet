# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::hg_files {

    require win_mozilla_build::install
    require win_mozilla_build::hg_install

    $mozbld = $win_mozilla_build::install_path

    if $win_mozilla_build::needed_mozbld_ver == '4.0.1' {
        $msys_dir = "${win_mozilla_build::install_path}\\msys2"
    } else {
        $msys_dir = "${win_mozilla_build::install_path}\\msys"
    }

    # Original Source https://github.com/mozilla/version-control-tools/blob/master/hgext/robustcheckout/__init__.py
    # Reference  https://bugzilla.mozilla.org/show_bug.cgi?id=1305485#c5
    file { "${mozbld}\\robustcheckout.py":
        content => file('win_mozilla_build/robustcheckout.py'),
    }
    file { "${win_mozilla_build::install_path}\\${msys_dir}\\etc\\cacert.pem":
        content => file('win_mozilla_build/cacert.pem'),
    }
    file { "${win_mozilla_build::program_files}\\mercurial\\mercurial.ini":
        content => file('win_mozilla_build/mercurial.ini'),
    }
    file { "${win_mozilla_build::cache_drive}\\hg-shared":
        ensure => directory,
    }
    # Resource from counsyl-windows
    windows::environment { 'HG_CACHE':
        value => "${win_mozilla_build::cache_drive}\\tooltool-cache",
    }
    # Resource from puppetlabs-acl
    acl { "${win_mozilla_build::cache_drive}\\hg-shared":
        target      => "${win_mozilla_build::cache_drive}\\hg-shared",
        permissions => {
            identity                   => 'everyone',
            rights                     => ['full'],
            perm_type                  => 'allow',
            child_types                => 'all',
            affects                    => 'all',
            inherit_parent_permissions => true,
        }
    }
}
