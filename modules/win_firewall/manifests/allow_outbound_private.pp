# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_firewall::allow_outbound_private {
  windowsfirewall { 'private':
    ensure                  => 'present',
    default_outbound_action => 'allow',
  }
}
