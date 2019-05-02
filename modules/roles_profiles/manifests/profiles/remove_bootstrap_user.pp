# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::remove_bootstrap_user {

    $user = 'relops'

    if $::operatingsystem == 'Darwin' {
        exec { "${user}_admin_group":
            command => "/usr/bin/dscl . -delete /Users/${user} || rm /private/var/db/dslocal/nodes/Default/users/${user}.plist",
            onlyif  => "/usr/bin/id ${user}",
        }
    }

    user { $user:
        ensure => absent
    }
}
