# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::google_chrome (
  String $version = '80.0.3987.122-1'
) {

  packages::linux_package_from_s3 { "google-chrome-stable_${version}_amd64.deb":
    private             => false,
    os_version_specific => false,
    type                => 'deb',
  }
}
