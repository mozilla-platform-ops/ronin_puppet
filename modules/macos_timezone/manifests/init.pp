# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @param timezone
#     The name of the timezone.
#

class macos_timezone (
    String $timezone = 'GMT'
) {

    case $::operatingsystem {
        'Darwin': {
            if ($::timezone != $timezone) {
                macos_utils::systemsetup {
                    'timezone':
                        setting => $timezone;
                }
            }
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }

}
