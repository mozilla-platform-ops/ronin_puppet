# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This class installs the latest Google Chrome on Ubuntu.
class linux_packages::google_chrome () {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          # Ensure apt is included
          include apt

          Exec['apt_update'] -> Package['google-chrome-stable']

          # Setup Google Chrome apt repository
          apt::source { 'google_repo':
            location => '[arch=amd64] https://dl.google.com/linux/chrome/deb/',
            release  => 'stable',
            key      => {
              id     => '4CCA1EAF950CEE4AB83976DCA040830F7FAC5991',
              source => 'https://dl.google.com/linux/linux_signing_key.pub',
            },
            repos    => 'main',
            include  => {
              'src' => false,
            },
            notify   => Exec['apt_update'],  # This ensures apt_update is triggered after the source is added
          }

          # Schedule for Chrome auto-updates
          schedule { 'update-chrome-schedule':
            period => weekly,
            repeat => 1,
          }

          exec { 'update-chrome-action':
            schedule => 'update-chrome-schedule',
            command  => '/usr/bin/apt-get update -o \
            Dir::Etc::sourcelist="sources.list.d/google-chrome.list" \
            -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"',
          }

          # Install Google Chrome stable version
          package { 'google-chrome-stable':
            ensure => 'latest',
          }
        }
        default: {
          fail("Cannot install Google Chrome on ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("Cannot install Google Chrome on ${facts['os']['name']}")
    }
  }
}
