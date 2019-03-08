# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

case $::operatingsystem {
    'Windows': {
        File {
            backup             => false,
            source_permissions => ignore,
        }
    }
    default: {
        # Default to 0:0, 0644 on POSIX
        File {
            owner  => 0,
            group  => 0,
            mode   => '0644',
            backup => false,
        }
    }
}

# Default node should always fail
node default {
  fail("Missing node classification for node ${networking['fqdn']}")
}
