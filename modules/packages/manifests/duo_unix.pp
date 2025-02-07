# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::duo_unix (
    Pattern[/^\d+\.\d+\.\d+$/] $version = '1.11.4',
) {

    packages::macos_package_from_s3 { "duo_unix-${version}.pkg":
        os_version_specific => true,
        type                => 'pkg',
    }
}
