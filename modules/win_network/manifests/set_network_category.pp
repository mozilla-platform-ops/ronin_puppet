# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_network::set_network_category (
    String $network_category
) {

    exec { 'set_category':
        command  => "Set-NetConnectionProfile -NetworkCategory ${network_category}",
        provider => powershell,
    }
}
