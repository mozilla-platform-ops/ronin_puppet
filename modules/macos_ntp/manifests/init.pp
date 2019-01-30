# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @param ensure
#     Ensure enabled or disabled
#
# @param ntp_server
#     The fqdn of the ntp server
#

class macos_ntp (
    Boolean $enabled = true,
    String  $ntp_server = 'time.apple.com'
) {
    if $enabled {
        macos_utils::systemsetup { 'usingnetworktime':
            setting => 'on'
        }
        macos_utils::systemsetup { 'networktimeserver':
            setting => $ntp_server
        }
    } else {
        macos_utils::systemsetup { 'usingnetworktime':
            setting => 'off'
        }
    }
}
