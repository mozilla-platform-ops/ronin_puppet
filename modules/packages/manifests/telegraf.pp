# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::telegraf (
    Pattern[/^\d+\.\d+\.\d+_?\d*$/] $version = '1.12.3',
) {
    # arm64 if Apple processor
    if /^Apple.*/ in $facts['processors']['models'] {
        $suffix = "-arm64"
    } else {
        $suffix = ""
    }

    packages::macos_package_from_s3 { "telegraf-${version}${suffix}.dmg":
        private             => false,
        os_version_specific => false,
        type                => 'dmg',
    }
}
