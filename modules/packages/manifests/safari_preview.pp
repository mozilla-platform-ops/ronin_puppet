# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::safari_preview {
  case $facts['os']['release']['major'] {
    # 22 == OS X 13
    '22': {
      packages::macos_package_from_s3 { 'SafariTechnologyPreview13.pkg':
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
      }
    }
    # 23 == OS X 14
    '23':  {
      packages::macos_package_from_s3 { 'SafariTechnologyPreview14.pkg':
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
      }
    }
    # 23 == OS X 14
    '24':  {
      packages::macos_package_from_s3 { 'SafariTechnologyPreview15.pkg':
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
      }
    }
    default: {
      # Handle default case here if needed
    }
  }
}
