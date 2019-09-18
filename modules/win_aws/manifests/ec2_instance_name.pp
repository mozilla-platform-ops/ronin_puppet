# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_aws::ec2_instance_name (
    String $instance_name,
    String $current_name,
    String $instance_nv_domain
) {
    $tcpip_param_key = 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters'

    if $instance_name != $current_name {
        exec { 'name_instance':
            command => "C:\\Windows\\System32\\wbem\\WMIC.exe computersystem where caption=\"${current_name}\" rename \"${instance_name}\"",
        }
    }
    registry_value { "${tcpip_param_key}\\Domain":
        type => string,
        data => $instance_nv_domain,
    }
    registry_value { "${tcpip_param_key}\\NV domain":
        type => string,
        data => $instance_nv_domain,
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1563289
