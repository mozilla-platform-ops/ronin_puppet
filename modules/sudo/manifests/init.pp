# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class sudo {

    concat { '/etc/sudoers':
        owner => $::root_user,
        group => $::root_group,
        mode  => '0440',
    }

    concat::fragment { '00-base':
        target  => '/etc/sudoers',
        content => template("${module_name}/sudoers-base.erb");
    }

    file { '/etc/sudoers.d':
        ensure => absent,
        force  => true,
    }
}
