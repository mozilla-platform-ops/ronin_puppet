# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::xcode (
    String $version,
) {

    packages::macos_package_from_s3 { "Xcode_${version}.dmg":
        private             => true,
        os_version_specific => true,
        type                => 'appdmg',
    }

    exec { 'accept_xcode_eula':
        command     => '/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -license accept',
        refreshonly => true,
        subscribe   => Packages::Macos_package_from_s3["Xcode_${version}.dmg"],
    }
}
