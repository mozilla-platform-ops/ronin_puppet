# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::webview2 {
  include chocolatey
  case $facts['os']['name'] {
    'Windows': {
      package { 'webview2-runtime':
        ensure   => 'latest',
        provider => 'chocolatey',
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
