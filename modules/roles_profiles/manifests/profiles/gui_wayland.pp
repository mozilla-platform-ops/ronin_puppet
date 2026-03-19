# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gui_wayland {
  case $facts['os']['name'] {
    'Ubuntu':{
      include linux_packages::ubuntu_desktop
      if $facts['os']['release']['full'] == '24.04' {
        class {
          'linux_gui_wayland':
            # TODO: use hiera data
            builder_user  => 'cltbld',
            builder_group => 'cltbld',
            builder_home  => '/home/cltbld',
            require       => Class['linux_packages::ubuntu_desktop'];
        }
      } else {
        fail("${$facts['os']['release']['full']} not supported")
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
