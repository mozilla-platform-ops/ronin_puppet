# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_aws::ec2_instance_config {

  $conf_file = "${facts['custom_win_programfiles']}\\Amazon\\Ec2ConfigService\\Settings\\Config.xml"

    file { $conf_file:
        content => file('win_aws/ec2_config.xml'),
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1562969
