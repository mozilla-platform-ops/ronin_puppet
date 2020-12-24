# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::scres (
    Pattern[/^\d+\.\d+\.\d+$/] $version = '1.0.0',
) {

    packages::macos_package_from_s3 { "scres-${version}.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
}
