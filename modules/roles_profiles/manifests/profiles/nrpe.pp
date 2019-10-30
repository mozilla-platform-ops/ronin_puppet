# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::nrpe {

    $nrpe_allowed_hosts = lookup('nrpe_allowed_hosts')

    class { 'nrpe':
        nrpe_allowed_hosts => $nrpe_allowed_hosts,
    }

    # Lookup nrpe checks in hiera and include them
    lookup('nrpe_checks', Array[String], 'unique', []).include
}
