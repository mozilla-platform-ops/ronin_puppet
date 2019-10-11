# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::nodejs (
    Pattern[/^\d+\.\d+\.\d+_?\d*$/] $version = '12.11.1',
) {

    # https://nodejs.org/dist/v12.11.1/node-v12.11.1.pkg
    # 8b42fa40fb96756dabfc43f7a69eaf4e10e5b78db3094dcc5469207f21992eb3

    packages::macos_package_from_s3 { "node-v${version}.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
}
