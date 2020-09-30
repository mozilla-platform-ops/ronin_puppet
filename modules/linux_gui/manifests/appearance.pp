# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class linux_gui::appearance {
    # include dirs::usr::local::bin
    # include users::root

    case $::operatingsystem {
        'Ubuntu': {
            include linux_packages::libglib20_bin

            # disable screensaver locking
            file {
                '/usr/share/glib-2.0/schemas/99_gsettings.gschema.override':
                    notify => Exec['update-gsettings'],
                    source => 'puppet:///modules/linux_gui/gsettings.gschema.override';
            }
            exec {
                'update-gsettings':
                    command     => '/usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas',
                    require     => Class['linux_packages::libglib20_bin'],
                    refreshonly => true;
            }

            # remove gnome-initial-setup as we do all configuration
            package {
                'gnome-initial-setup':
                    ensure => 'absent';

            }

            # avoid auth prompt to create a color managed device
            file {
                '/etc/polkit-1/localauthority/50-local.d/45-allow.colord.pkla':
                    source => 'puppet:///modules/linux_gui/colord.pkla';
            }
        }
        default: {
            fail("Don't know how to set up GUI appearance on ${::operatingsystem}")
        }
    }
}
