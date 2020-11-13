# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::disable_network_warnings {

    # Resource from puppetlabs-scheduled_task
    scheduled_task { 'disable_firewall notifications':
        ensure    => 'present',
        command   => "${facts['custom_win_system32']}\\netsh.exe",
        arguments => 'firewall set notifications mode = disable profile = all',
        enabled   => true,
        trigger   => [{
            'schedule' => 'logon',
            'user_id'  => ''
        }],
    }
}
