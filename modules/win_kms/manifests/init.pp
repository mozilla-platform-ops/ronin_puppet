# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_kms {
  if $facts['os']['name'] == 'Windows' {
    include win_kms::fw_exception
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1510828
