# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::nrpe {

    packages::macos_package_from_s3 { 'nrpe-2.14-moz1.dmg':
        os_version_specific => true,
        type                => 'dmg',
    }
}
