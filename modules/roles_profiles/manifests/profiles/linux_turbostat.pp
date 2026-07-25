# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs turbostat via linux-tools and grants cltbld passwordless access.
class roles_profiles::profiles::linux_turbostat {

  require linux_packages::linux_tools

  sudo::custom { 'allow_cltbld_turbostat':
    user    => 'cltbld',
    command => '/usr/bin/turbostat',
  }

}
