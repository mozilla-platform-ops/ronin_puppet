# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::openssl (
    String $version = '1.1.1k',
) {

    packages::macos_package_from_s3 { "openssl-${version}.pkg":
        os_version_specific => true,
        type                => 'pkg',
    }
}
