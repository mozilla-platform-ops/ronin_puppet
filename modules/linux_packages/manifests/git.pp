# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::git {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04': {
          package {
            'git':
              ensure => present;
          }
        }
        '22.04': {
          packages::linux_package_from_s3 { 'git_2.42.0-0ppa1~ubuntu18.04.1_amd64.deb':
            private             => false,
            os_version_specific => false,
            type                => 'deb',
            file_destination    => '/usr/local/bin/magick',
            checksum            => '40e17918bff5544c252005433a565eecfe653228048108d7ff79de0548b9d552',  # sha256
          }
          packages::linux_package_from_s3 { 'git-man_2.42.0-0ppa1~ubuntu18.04.1_all.deb':
            private             => false,
            os_version_specific => false,
            type                => 'deb',
            file_destination    => '/usr/local/bin/magick',
            checksum            => '56e6d53f07e3ed67b2e5c7602674f3951014d3591b6dcab5013ed69540784e3c',  # sha256
          }
        }
        default: {
          fail("cannot install on ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("Cannot install on ${facts['os']['name']}")
    }
  }
}
