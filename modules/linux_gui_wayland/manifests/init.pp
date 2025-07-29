# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_gui_wayland (
  $builder_user,
  $builder_group,
  $builder_home
) {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '24.04': {
          # TODO: set resolutions

          # install fonts (used to be installed by ubuntu-desktop in <2204?)
          $packages = ['fonts-kacst', 'fonts-kacst-one', 'fonts-liberation', 'fonts-stix',
          'fonts-unfonts-core', 'fonts-unfonts-extra', 'fonts-vlgothic']

          package { $packages:
            ensure => installed,
          }

          # packages to remove
          # sudo apt remove --autoremove gnome-initial-setup
          # about:
          #   gnome-initial-setup: popus up first-start dialog
          $remove_packages = ['gnome-initial-setup']
          package { $remove_packages:
            ensure => absent,
          }

          # pip.conf
          file {
            ["${builder_home}/.pip"]:
              ensure => directory,
              group  => $builder_group,
              mode   => '0755',
              owner  => $builder_user;
            "${builder_home}/.pip/pip.conf":
              owner  => $builder_user,
              group  => $builder_group,
              mode   => '0644',
              source => "puppet:///modules/${module_name}/pip.conf";
          }
        }
        default: {
          fail ("linux_gui_wayland does not support Ubuntu version ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("linux_gui_wayland is not supported on ${facts['os']['name']}")
    }
  }
}
