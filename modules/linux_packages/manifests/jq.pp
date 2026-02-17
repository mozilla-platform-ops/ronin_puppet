# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::jq {
  # Ensure the 'jq' package is installed (also includes yq)
  package { 'jq':
    ensure   => installed,
    name     => 'jq',
    provider => 'apt',
  }
}
