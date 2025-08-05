# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gui {
  case $facts['os']['name'] {
    'Darwin': {
      class { 'macos_mobileconfig_profiles::desktop_background':
        ensure => 'absent',
      }
      include macos_utils::show_full_name
      include macos_utils::show_scroll_bars
    }
    'Ubuntu':{
      # this is for x11, see gui_wayland.pp for wayland
      include linux_packages::ubuntu_desktop
      if $facts['os']['release']['full'] in ['18.04', '22.04', '24.04'] {
        include roles_profiles::profiles::cltbld_user
        class {
          'linux_gui':
            # TODO: use hiera data
            builder_user  => 'cltbld',
            builder_group => 'cltbld',
            builder_home  => '/home/cltbld',
            require       => [
              Class['linux_packages::ubuntu_desktop'],
              User['cltbld'],
            ],
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
