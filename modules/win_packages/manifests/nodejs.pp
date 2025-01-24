# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::nodejs {
  $nodejs_version = lookup('win-worker.nodejs.version')

  ## Install the latest version of chrome via chocolatey
  package { 'nodejs-lts':
    ensure   => $nodejs_version,
    provider => 'chocolatey',
  }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1943534
