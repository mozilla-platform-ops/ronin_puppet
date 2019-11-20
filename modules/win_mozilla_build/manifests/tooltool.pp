# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::tooltool {

    require win_mozilla_build::install
    require win_mozilla_build::modifications

    $builds         = $win_mozilla_build::builds_dir
    $tooltool_cache = "${builds}\\tooltool_cache"

    file { "${win_mozilla_build::install_path}\\tooltool.py":
        source => 'https://raw.githubusercontent.com/mozilla-releng/tooltool/master/client/tooltool.py',
    }
    file { $tooltool_cache:
        ensure => directory,
    }
    # Resource from counsyl-windows
    windows::environment { 'TOOLTOOL_CACHE':
        value => $tooltool_cache,
    }
    # Resource from puppetlabs-acl
    acl { "${win_mozilla_build::system_drive}\\tooltool-cache":
        target                     => $tooltool_cache,
        permissions                =>   {
                                            identity    => 'everyone',
                                            rights      => ['full'],
                                            type        => 'allow',
                                            child_types => 'all',
                                            affects     => 'all'
                                        },
        inherit_parent_permissions => true,
    }
    file { "${builds}\\relengapi.tok":
        content   => $win_mozilla_build::tooltool_tok,
        show_diff => false,
    }
    # This script will get the SSL Server Certificate for https://tooltool.mozilla-releng.net
    # and will add it to the local user store
    # Without the cert in the local user store tooltool will hit SSL errors when fetching a package
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1546827
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1548641
    exec { 'install_tooltool_cert':
        command  => file('win_mozilla_build/tooltool_cert_install.ps1'),
        provider => powershell,
    }
}
