# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_snmpd {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          # load in secrets from vault/hiera
          $snmpd_ro_secret = lookup('snmpd.ro_community', { default_value => undef })

          # only do this block if secret is set
          if $snmpd_ro_secret and $snmpd_ro_secret != '' {
            # include vs require? still need to do ordering...
            include linux_packages::snmpd

            service { 'snmpd':
              ensure  => running,
              enable  => true,
              require => Class['linux_packages::snmpd'];
            }

            # deliver our config (require linux_packages::snmpd)
            #   /etc/snmp/snmpd.conf
            file {
              default: * => $shared::file_defaults;

              '/etc/snmp/snmpd.conf':
                ensure  => file,
                content => template('linux_snmpd/snmpd.conf.erb'),
                mode    => '0644',
                notify  => Service['snmpd'];
            }
          }
          else {
            notice('snmpd_ro_community is not set, skipping snmpd configuration')
          }
        }
        default: {
          fail("Ubuntu ${facts['os']['release']['full']} is not supported")
        }
      }
    }
    default: {
      fail("${facts['os']['name']} is not supported")
    }
  }
}
