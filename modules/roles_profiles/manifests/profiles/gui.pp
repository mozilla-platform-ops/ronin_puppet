# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gui {

    case $::operatingsystem {
        'Darwin': {
            class { 'macos_mobileconfig_profiles::desktop_background':
                ensure => 'absent',
            }
            include macos_utils::set_desktop_background
            include macos_utils::show_full_name
            include macos_utils::show_scroll_bars
        }
        'Ubuntu':{
            include linux_packages::ubuntu_desktop
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
