# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::linux_base {
  case $facts['os']['name'] {
    'Ubuntu': {
      # use require (vs include) as we want ordering
      require roles_profiles::profiles::relops_users
      require roles_profiles::profiles::sudo
      require roles_profiles::profiles::locale
      require roles_profiles::profiles::timezone
      require roles_profiles::profiles::ntp
      require roles_profiles::profiles::motd
      # both of these remove the bootstrap accounts/sudoers, so run later
      require roles_profiles::profiles::users
      require roles_profiles::profiles::securitize

      require disable_services
      require grub
      # fix for ubuntu packaging bug
      require linux_packages::testresources

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
