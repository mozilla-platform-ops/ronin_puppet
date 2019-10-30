# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class nrpe::settings {

    $nrpe_etcdir = '/etc/nagios/'

    case $facts['os']['name'] {
        'Darwin': {
            $plugins_dir = '/usr/local/libexec'
        }
        default: {
            fail("${$facts['os']['name']} not suported")
        }
    }
}
