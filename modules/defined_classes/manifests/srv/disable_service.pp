# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define defined_classes::srv::disable_service ($service=$title) {

    service { $service:
        ensure => 'stopped',
        enable => false,
    }
}
