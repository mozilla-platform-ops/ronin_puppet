# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::td-agent {

    # https://packages.treasuredata.com.s3.amazonaws.com/3/macosx/td-agent-3.1.1-0.dmg
 
    packages::macos_package_from_s3 { 'td-agent-3.1.1-0.dmg':
        private             => false,
        os_version_specific => false,
        type                => 'dmg',
    }
}
