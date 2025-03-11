# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ssh {
  case $facts['os']['name'] {
    'Windows': {
      $ssh_program_data     = "${facts['custom_win_programdata']}\\ssh"
      $programfiles         = $facts['custom_win_programfiles']
      $firewall_port        = lookup('windows.datacenter.ports.ssh')
      $firewall_rule_name   = 'SSH'

      $relops_key = lookup('windows.winaudit_ssh')

      class { 'win_users::administrator::authorized_keys':
        relops_key => $relops_key,
      }
      case $facts['custom_win_os_version'] {
        'win_10_2009': {
            include  win_openssh::schd_task
      }
        default: {
            include win_openssh::add_openssh
            include win_openssh::service
        }
      }
      windows_firewall::exception { "allow_${firewall_rule_name}_mdc1":
        ensure       => present,
        direction    => 'in',
        action       => 'allow',
        enabled      => true,
        protocol     => 'TCP',
        local_port   => $firewall_port,
        remote_port  => 'any',
        display_name => "${firewall_rule_name}_mdc1",
        description  => "${firewall_rule_name}_mdc1",
      }
      include win_openssh::configuration
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
