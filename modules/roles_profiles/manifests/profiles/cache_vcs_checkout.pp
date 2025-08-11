# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::cache_vcs_checkout {
  case $facts['os']['name'] {
    'Windows': {
      include win_filesystem::cache_mozilla_unified
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
