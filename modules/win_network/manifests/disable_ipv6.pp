# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_network::disable_ipv6 {

    # Using puppetlabs-registry
    if $facts['custom_win_location'] == 'datacenter' {
        registry_value { 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\DisabledComponents':
            ensure => present,
            type   => dword,
            data   => '0xFF',
        }
    } else {
        fail('IPv6 is to only be disabled for hardware nodes')
    }
}
