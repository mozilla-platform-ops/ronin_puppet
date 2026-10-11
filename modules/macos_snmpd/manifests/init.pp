# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# macos_snmpd configures net-snmp on macOS workers so marlin can poll them
# the same way it polls Linux workers (snmpd extend OIDs for gw_status and
# worker_pool_id, plus the standard MIBs that the linux SNMP services use).
#
# Installation strategy:
#   net-snmp is installed via the standard packages::macos_package_from_s3
#   pattern (see packages::net_snmp). The S3-hosted .pkg drops the snmpd
#   binary at the path specified by $snmpd_path (default /usr/sbin/snmpd —
#   adjust if the package installs elsewhere, e.g. /opt/net-snmp/sbin/snmpd).
#
# Hiera-driven on/off (same shape as linux_snmpd):
#   snmpd::enabled: false
class macos_snmpd (
  String $snmpd_path = '/usr/sbin/snmpd',
) {
  $enabled = lookup('snmpd.enabled', { default_value => true })

  if $enabled {
    $snmpd_ro_secret = lookup('snmpd.ro_community', { default_value => undef })

    if $snmpd_ro_secret and $snmpd_ro_secret != '' {
      require packages::net_snmp

      file {
        default:
          owner => 'root',
          group => 'wheel';

        '/etc/snmp':
          ensure => directory,
          mode   => '0755';

        '/etc/snmp/snmpd.conf':
          ensure  => file,
          content => epp("${module_name}/snmpd.conf.epp", {
            'snmpd_ro_secret' => $snmpd_ro_secret,
          }),
          mode    => '0644',
          notify  => Service['net.net-snmp.snmpd'];

        '/usr/local/bin/snmp_check_gw.sh':
          ensure => file,
          source => "puppet:///modules/${module_name}/snmp_check_gw.sh",
          mode   => '0755';

        '/usr/local/bin/snmp_worker_pool_id.sh':
          ensure => file,
          source => "puppet:///modules/${module_name}/snmp_worker_pool_id.sh",
          mode   => '0755';

        '/Library/LaunchDaemons/net.net-snmp.snmpd.plist':
          ensure  => file,
          content => epp("${module_name}/launchdaemon.plist.epp", {
            'snmpd_path' => $snmpd_path,
          }),
          mode    => '0644',
          notify  => Service['net.net-snmp.snmpd'];
      }

      service { 'net.net-snmp.snmpd':
        ensure  => running,
        enable  => true,
        require => [
          File['/Library/LaunchDaemons/net.net-snmp.snmpd.plist'],
          Class['packages::net_snmp'],
        ],
      }
    }
    else {
      notice('snmpd.ro_community is not set, skipping macos_snmpd configuration')
    }
  }
  else {
    service { 'net.net-snmp.snmpd':
      ensure => stopped,
      enable => false,
    }
  }
}
