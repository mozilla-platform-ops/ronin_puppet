# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ec2_instance_configuration {

    case $::operatingsystem {
        'Windows': {

            $instance_name      = $facts['custom_win_instance_id']
            $current_name       = $facts['networking']['hostname']
            $instance_nv_domain = "${facts['custom_win_workertype']}.${facts['custom_win_availability_zone']}.mozilla.com"

            class {  'win_aws::ec2_instance_name':
                instance_name      => $instance_name,
                current_name       => $current_name,
                instance_nv_domain => $instance_nv_domain,
            }

            include win_aws::ec2_instance_config

            # Bug List
            # Config
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1562969
            # Name
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1563289
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
