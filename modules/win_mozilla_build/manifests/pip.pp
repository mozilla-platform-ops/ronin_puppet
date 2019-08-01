# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::pip {

    require win_mozilla_build::install

    file {"${win_mozilla_build::programdata}\\pip":
        ensure => directory,
    }
    file { "${win_mozilla_build::programdata}\\pip\\pip.ini":
        content => file('win_mozilla_build/pip.conf'),
    }
    file {"${win_mozilla_build::cache_drive}\\pip-cache":
        ensure => directory,
    }
    # Resource from puppetlabs-acl
    acl { "${win_mozilla_build::cache_drive}\\pip-cache":
        target      => "${win_mozilla_build::cache_drive}\\pip-cache",
        permissions => {
            identity                   => 'everyone',
            rights                     => ['full'],
            type                       => 'allow',
            child_types                => 'all',
            affects                    => 'all',
            inherit_parent_permissions => true,
        }
    }
    # Resource from counsyl-windows
    windows::environment{ 'PIP_DOWNLOAD_CACHE':
        value => "${win_mozilla_build::cache_drive}\\pip-cache",
    }
}
