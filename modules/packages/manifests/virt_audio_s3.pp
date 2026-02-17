# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::virt_audio_s3 (
    String $version = '0.5.0',
){

    packages::macos_package_from_s3 { "BlackHole16ch.v${version}.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
    packages::macos_package_from_s3 { "BlackHole2ch.v${version}.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
}
