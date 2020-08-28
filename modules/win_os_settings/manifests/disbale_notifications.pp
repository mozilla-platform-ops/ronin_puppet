# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::disbale_notifications {

  # Using puppetlabs-registry
    registry::value { 'NoNewAppAlert':
        key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer',
        type => dword,
        data => '1',
    }
    registry_key { 'HKLM\System\CurrentControlSet\Control\Network\NewNetworkWindowOff':
        ensure => present
    }
    #registry::value { 'DisableNotifications':
        #key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications',
        #type => dword,
        #data => '1',
    #}
    exec { 'disable_fw_notifications':
        command     =>
            "${facts[custom_win_system32]}\\netsh.exe firewall set notifications mode = disable profile = all",
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1562024
# https://bugzilla.mozilla.org/show_bug.cgi?id=1373551
# https://bugzilla.mozilla.org/show_bug.cgi?id=1397201#c58"
