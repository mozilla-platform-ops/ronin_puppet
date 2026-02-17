# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::py2 {
  # we're not installing py2 anymore, so remove it
  package { 'python':
    ensure   => absent,
  }
  package { 'python-pip':
    ensure => absent,
  }
}
