# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::safari_webdriver_v2 (
    Optional[String] $ensure = 'present',
) {
    mac_profiles_handler::manage { 'Ryans-MacBook-Pro.DA287EA6-F234-4B9D-9086-3DC6EE1D15B9':
        ensure      => $ensure,
        file_source => 'puppet:///modules/macos_mobileconfig_profiles/safari_dev_menu.mobileconfig',
    }

    packages::macos_package_from_s3 { "remote_auto_plist-Signed.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
}
