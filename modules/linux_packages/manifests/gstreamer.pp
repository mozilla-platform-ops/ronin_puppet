# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::gstreamer {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04': {
          package {
            # In ubuntu 16.04, gstreamer0.10-ffmpeg was replaced with gstreamer1.0-libav
            'gstreamer1.0-libav':
              ensure => 'latest';
            ['gstreamer1.0-plugins-ugly','gstreamer1.0-plugins-base']:
              ensure => 'latest';
            'gstreamer1.0-plugins-bad':
              ensure => 'latest';
            'gstreamer1.0-plugins-good':
              ensure => 'latest';
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
