# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::visual_studio_build_tools {

  case $facts['os']['name'] {
    'Windows': {
        include win_packages::vs_build_tools
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
