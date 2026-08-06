# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class users::remove_relops_pw {

  user { 'relops':
    ensure => present,
  }

  exec { 'remove relops password':
    command => '/usr/sbin/usermod --password "*" relops',
    unless  => "/usr/bin/getent shadow relops | /usr/bin/grep -q '^relops:[*]:'",
  }

}
