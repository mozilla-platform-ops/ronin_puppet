# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# ia32-libs are needed by b2g emulator tests
class linux_packages::ia32libs {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04': {
          # from Alin Selagea, 2017-03-14:
          # In ubuntu 16.04, ia32-libs was replaced with lib32z1 lib32ncurses5
          # When I tried to install ia32-libs, I received the error:
          # However the following packages replace it:
          # lib32z1 lib32ncurses5
          package {
            'lib32ncurses5':
              ensure => 'latest';
          }
        }
        '22.04': {
          true
        }

        # Note from Michelle Goossens at 2023-01-31:
        # This block is purely for lib32ncurse5, which we may no longer need at all (or in 32 bits).
        # '22.04': {
        #   # from Michelle Goossens, 2023-01-20:
        #   # lib32ncurses5 no longer exists in Ubuntu 22.04. I assume that
        #   # we want libncurses5 in 32 bit, so we install the i386 variant.
        #   exec {
        #     'add i386 packages':
        #         path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
        #         user    => $::user,
        #         command => 'sudo dpkg --add-architecture i386',
        #   }
        #   exec {
        #     'apt update after adding i386':
        #         path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
        #         user    => $::user,
        #         command => 'sudo apt update',
        #   }
        #   package {
        #     'libncurses5:i386':
        #       ensure => 'latest';
        #   }
        # }
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
