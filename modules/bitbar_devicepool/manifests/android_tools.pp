# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::android_tools {

  vcsrepo { '/home/bitbar/android-tools':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/mozilla-platform-ops/android-tools.git',
    user     => 'bitbar',
  }

}
