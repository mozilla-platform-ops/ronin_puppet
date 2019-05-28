# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class users::all_users (
    Hash $all_users,
) {
    # Iterate over the $all_users hash and create virtual resources for all users
    # which can then be realized later in profile based on group definitions
    $all_users.each | String $user, Array $ssh_keys | {
        @users::single_user { $user:
            ssh_keys => $ssh_keys,
        }
    }

    # SIP workaround; module assumes sip is off
    case $::operatingsystem {
        'Darwin': {
            exec { 'fix_account_plist_perms':
                command => '/bin/chmod g+r /var/db/dslocal/nodes/Default && /bin/chmod -R g+r /var/db/dslocal/nodes/Default/users || exit 0',
                onlyif  =>  [
                    '/bin/test -d /var/db/dslocal/nodes/Default/users',
                ],
            }
        }
    }
}
