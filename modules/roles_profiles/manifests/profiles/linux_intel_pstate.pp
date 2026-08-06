# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs Intel pstate performance control and grants cltbld access to it.
class roles_profiles::profiles::linux_intel_pstate {

  require linux_intel_pstate

  sudo::custom { 'allow_cltbld_set_intel_pstate_perf_pct':
    user    => 'cltbld',
    command => '/usr/local/bin/set-intel-pstate-perf-pct',
  }

}
