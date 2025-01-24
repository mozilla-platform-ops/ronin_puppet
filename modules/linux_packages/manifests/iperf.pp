# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::iperf {
  # Ensure the 'iperf3' package is installed
  package { 'iperf3':
    ensure   => installed,
    name     => 'iperf3',
    provider => 'apt',
  }
}
