# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::imagemagick {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04': {

          # 6.9
          package { 'imagemagick':
            ensure   => present,
          }
          # 7.0, 'Complete portable application on Linux'
          #   from https://imagemagick.org/script/download.php
          packages::linux_package_from_s3 { 'magick-v7.0.10-31':
              private             => false,
              os_version_specific => false,
              type                => 'bin',
              file_destination    => '/usr/local/bin/magick',
              checksum            => '87431900e4446517630adb0bceef8f08634e6cd444513482f8f45c4b245b8c65',  # sha256
          }
        }
        '22.04': {
          # 6.9
          package { 'imagemagick':
            ensure   => present,
          }
        }
        default: {
          fail("Ubuntu ${::operatingsystemrelease} is not supported")
        }
      }
    }
    default: {
      fail("Cannot install on ${::operatingsystem}")
    }
  }
}
