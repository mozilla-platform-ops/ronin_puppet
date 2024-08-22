# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This class installs Google Chrome on Ubuntu.
class linux_packages::google_chrome () {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04': {
          include apt

          Exec['apt_update'] -> Package['google-chrome-stable']

          # setup chrome source
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
            notify   => Exec['apt_update'],
          }

          # configure auto-update
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

          # install chrome
          package {
            'google-chrome-stable':
              # on 1804, latest no longer works missing packages (won't be created for deprecated release)
              #  `google-chrome-stable : Depends: libgcc-s1 (>= 4.2) but it is not installable`
              # need to upgrade to newer os version
              ensure => '127.0.6533.119-1';
          }
        }
        '22.04','24.04': {
          include apt

          Exec['apt_update'] -> Package['google-chrome-stable']

          # setup chrome source
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
            notify   => Exec['apt_update'],
          }

          # configure auto-update
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

          # install chrome
          package {
            'google-chrome-stable':
              # on 1804, latest no longer works missing packages (won't be created for deprecated release)
              #  `google-chrome-stable : Depends: libgcc-s1 (>= 4.2) but it is not installable`
              # need to upgrade to newer os version
              ensure => 'latest';
          }
        }
        default: {
          fail("cannot install on ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("cannot install on ${facts['os']['name']}")
    }
  }
}
