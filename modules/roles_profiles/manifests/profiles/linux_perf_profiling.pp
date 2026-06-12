# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs the linux-tools package (provides `perf`) and grants cltbld
# sudo access to run it. Used by Linux talos roles to support performance
# profiling investigations (bug 2031822).
class roles_profiles::profiles::linux_perf_profiling {

  require linux_packages::linux_tools

  sudo::custom { 'allow_cltbld_perf':
    user    => 'cltbld',
    command => '/usr/bin/perf',
  }

}
