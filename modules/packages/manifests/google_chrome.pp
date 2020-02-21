# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::google_chrome (
    String $version = 'v80.0.3987.106',
) {

    packages::macos_package_from_s3 { "googlechrome_${version}.dmg":
        private             => false,
        os_version_specific => true,
        type                => 'appdmg',
    }
}
