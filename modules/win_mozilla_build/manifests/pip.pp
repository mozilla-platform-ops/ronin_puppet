# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::pip {

    require win_mozilla_build::install

    file {"${win_mozilla_build::programdata}\\pip":
        ensure => directory,
    }
    file { "${win_mozilla_build::programdata}\\pip\\pip.ini":
        content => file('win_mozilla_build/pip.ini'),
    }
    windows::environment { 'pip_cache':
        value => "${win_mozilla_build::systemdrive}\\pip-cache",
    }
    acl { "${win_mozilla_build::systemdrive}\\pip-cache":
        target      => "${win_mozilla_build::systemdrive}\\tooltool-cache",
        permissions => {
            identity                   => 'everyone',
            rights                     => ['full'],
            type                       => 'allow',
            child_types                => 'all',
            affects                    => 'all',
            inherit_parent_permissions => true,
        }
    }
    windows::environment{ 'PIP_DOWNLOAD_CACHE':
        value => "${win_mozilla_build::systemdrive}\\tooltool-cache",
    }
}
