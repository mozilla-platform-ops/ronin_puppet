# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class microsoft_store::init {
  case $facts['os']['name'] {
    'Windows': {
      include microsoft_store::av1
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
