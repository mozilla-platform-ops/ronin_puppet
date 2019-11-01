# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::java_developer_package_for_osx {

    # https://download.developer.apple.com/Developer_Tools/java_for_os_x_2013005_developer_package/java_for_os_x_2013005_dp__11m4609.dmg
    # the signing certificate expired Oct 24, 2019
    # I expanded and flattened the package (without signing)
    packages::macos_package_from_s3 { 'java_for_os_x_2013005_dp__11m4609_unsigned.dmg':
        private             => true,
        os_version_specific => true,
        type                => 'dmg',
    }
}
