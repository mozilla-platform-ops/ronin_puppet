# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ec2_instance_configuration {

    case $::operatingsystem {
        'Windows': {

            include win_aws::ec2_config

            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1562969
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
