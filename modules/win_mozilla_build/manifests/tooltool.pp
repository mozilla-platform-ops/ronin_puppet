# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::tooltool {

    require win_mozilla_build::install


    file { "${win_mozilla_build::install_path}\\tooltool.py":
        content => file('win_mozilla_build/tooltool.py'),
    }
    file {"${win_mozilla_build::system_drive}\\tooltool-cache":
        ensure => directory,
    }
    windows::environment { 'TOOLTOOL_CACHE':
        value => "${win_mozilla_build::cache_drive}\\tooltool-cache",
    }
    acl { "${win_mozilla_build::system_drive}\\tooltool-cache":
        target                     => "${win_mozilla_build::systemdrive}\\tooltool-cache",
        permissions                =>   {
                                            identity    => 'everyone',
                                            rights      => ['full'],
                                            type        => 'allow',
                                            child_types => 'all',
                                            affects     => 'all'
                                        },
        inherit_parent_permissions => true,
    }
}
