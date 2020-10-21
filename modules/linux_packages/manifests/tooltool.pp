# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::tooltool {

    packages::linux_package_from_s3 { 'tooltool.py-v1':
        private             => false,
        os_version_specific => false,
        type                => 'bin',
        file_destination    => '/usr/local/bin/tooltool.py',
        checksum            => 'e75c2b5ab9c83f33e3788e85c8e401b2825be9bd1530f4c2459d4cb3f4488cb9',
    }
}
