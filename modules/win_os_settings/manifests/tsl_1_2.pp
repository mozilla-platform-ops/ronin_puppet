# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::tsl_1_2 {

    $tsl_key    = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2"
    $client_key = "${tsl_key}\\Client"
    $server_key = "${tsl_key}\\Server"

    registry_key { $tsl_key:
        ensure => present,
    }
    registry_key { $client_key:
        ensure => present,
    }
    registry_key { $server_key:
        ensure => present,
    }
    registry_value { "${client_key}\\DisabledByDefault":
        ensure => present,
        type   => dowrd,
        data   => 0
    }
    registry_value { "${server_key}\\DisabledByDefault":
        ensure => present,
        type   => dowrd,
        data   => 0
    }
}
