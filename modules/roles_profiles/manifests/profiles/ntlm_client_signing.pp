# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ntlm_client_signing {
  case $facts['os']['name'] {
    'Windows': {
      include win_os_settings::ntlm_client_signing

      # Bug List
      # https://bugzilla.mozilla.org/show_bug.cgi?id=2092632
    }
    default : {
      fail("${facts['os']['name']} not supported")
    }
  }
}
