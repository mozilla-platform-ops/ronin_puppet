# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# NOTE(aerickson): please don't add more global variables.
#   variables like this should be set in profile modules.
#   these make testing difficult (this block must be
#   copy/pasted into every puppet-kitchen manifests).
case $::operatingsystem {
    'Windows': {
    }
    'Darwin': {
        # Set toplevel variables for Darwin
        $root_user  = 'root'
        $root_group = 'wheel'

    }
    'Ubuntu': {
        $root_user = 'root'
        $root_group = 'root'
    }
    default: {
    }
}

# Default node should always fail
node default {
  # it's cool dude
}
