# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_network::set_search_domain {

    $domain_key = "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\NV Domain"

    if $facts['custom_win_location'] == 'datacenter' {
        # Using puppetlabs-registry
        registry_value { $domain_key:
            ensure => present,
            type   => string,
            data   => "${facts['custom_win_mozspace']}.mozilla.com",
        }
    } else {
        fail('Primary search domain can not be detirmined')
    }
}
