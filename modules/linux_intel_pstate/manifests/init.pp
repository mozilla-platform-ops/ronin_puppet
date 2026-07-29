# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs the privileged helper used to set Intel pstate performance limits.
class linux_intel_pstate {

  file { '/usr/local/bin/set-intel-pstate-perf-pct':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/linux_intel_pstate/set-intel-pstate-perf-pct',
  }

}
