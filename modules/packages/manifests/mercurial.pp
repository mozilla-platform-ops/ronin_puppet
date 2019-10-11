# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::mercurial (
    Pattern[/^\d+\.\d+(\.\d+)?_?\d*$/] $version = '5.1',
) {

    packages::macos_package_from_s3 { "Mercurial-${version}-macosx10.14.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
}
