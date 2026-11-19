# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::linux_base {
  case $facts['os']['name'] {
    'Ubuntu': {
      # use require (vs include) as we want ordering
      require roles_profiles::profiles::relops_users
      require roles_profiles::profiles::users
      require roles_profiles::profiles::sudo
      require roles_profiles::profiles::locale
      require roles_profiles::profiles::timezone
      require roles_profiles::profiles::ntp
      require roles_profiles::profiles::motd

      Class['roles_profiles::profiles::sudo'] -> Class['roles_profiles::profiles::securitize']
      Class['roles_profiles::profiles::relops_users'] -> Class['roles_profiles::profiles::securitize']

      # this removes the bootstrap accounts, so run later
      require roles_profiles::profiles::securitize

      # Exact hostnames allow a monitored control without changing its branch.
      $network_manager_control_hosts = lookup('linux_network_manager_control_hosts', Array[String], 'first', [])
      class { 'disable_services':
        network_manager_enabled_1804 => !($facts['networking']['hostname'] in $network_manager_control_hosts),
      }
      require disable_services
      require grub
      # fix for ubuntu packaging bug
      require linux_packages::testresources

      if $facts['os']['release']['full'] == '24.04' {
        require linux_packages::ca_certificates
        require linux_packages::xz_utils
        require linux_packages::openssh
        require linux_packages::curl
      }

      # should be requires above, but fight that battle another day
      include linux_snmpd

      # TODO:
      # - add auditd
      # - add sending of logs to log aggregator/relay
      # - repo pinning
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
