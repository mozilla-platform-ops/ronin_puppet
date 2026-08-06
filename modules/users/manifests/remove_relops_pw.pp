# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class users::remove_relops_pw {
  # WARNING: locking this bootstrap account before provisioning SSH access can
  # lock out the host. Profiles that include this class must order
  # Exec['remove relops password'] after their access resources, as
  # roles_profiles::profiles::securitize does.

  user { 'relops':
    ensure => present,
  }

  exec { 'remove relops password':
    command => '/usr/sbin/usermod --password "*" relops',
    # Match only a shadow entry whose password field is `*`. The bootstrap
    # image lacks /usr/bin/grep, so use the POSIX shell's built-in `case`.
    unless  => '/bin/sh -c \'case "$(/usr/bin/getent shadow relops)" in relops:[*]:*) exit 0 ;; *) exit 1 ;; esac\'',
  }

}
