# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_gui(
    $builder_user,
    $builder_group,
    $builder_home
    # $on_gpu,
    # $screen_width,
    # $screen_height,
    # $screen_depth,
    # $refresh
) {
    # include config
    # include users::builder
    include linux_gui::appearance

    # $nvidia_version = '361.42'

    case $::operatingsystem {
        Ubuntu: {
            # The new moonshot hardware GPU workers have an intel gpu.
            $use_nvidia = false
            $on_gpu = true

            # Remove the nvidia packages so they do not conflict with intel.
            package {
                'nvidia-*':
                    ensure => absent;
            }

            # install the window manager and its prereqs
            # done in roles_profiles::profiles::gui

            # and the latest version of gnome-settings-daemon; older versions crash
            # (Bug 846348)
            include linux_packages::gnome_settings_daemon
            # Bug 859972: xrestop is needed for talos data collection
            include linux_packages::xrestop

            file {
                # Bug 1027345
                # Auto-detection of X settings works fine, but it would be
                # better to have all needed settings generated from the template.
                # Special-casing NVidia GPUs for now.
                '/etc/X11/Xwrapper.config':
                    content => template("${module_name}/Xwrapper.config.erb"),
                    notify  => Service['x11'];

                # this is the EDID data from an Extron EDID adapter configured for 1200x1600
                '/etc/X11/edid.bin':
                    source => "puppet:///modules/${module_name}/edid.bin";

                '/etc/xdg/autostart/jockey-gtk.desktop':
                    content => template("${module_name}/jockey-gtk.desktop");

                '/etc/xdg/autostart/deja-dup-monitor.desktop':
                    content => template("${module_name}/deja-dup-monitor.desktop");

                "${users::builder::home}/.xsessionrc":
                    content => "DESKTOP_SESSION=ubuntu\n",
                    owner   => $builder_user,
                    group   => $builder_group,
                    mode    => '0644',
                    notify  => Service['x11'];

                # make sure the builder user doesn't have any funny business
                [ "${builder_home}/.xsession",
                  "${builder_home}/.xinitrc",
                  "${builder_home}/.Xsession"]:
                    ensure => absent;
            }

            case $::operatingsystemrelease {
                18.04: {
                    $gpu_bus_id = 'PCI:0:02:0'
                    file {
                        '/etc/X11/xorg.conf':
                            ensure  => present,
                            content => template("${module_name}/xorg.conf.u16.erb"),
                            notify  => Service['x11'];
                        '/lib/systemd/system/x11.service':
                            content => template("${module_name}/x11.service.erb"),
                            notify  => Service['x11'];
                        '/lib/systemd/system/xvfb.service':
                            content => template("${module_name}/xvfb.service.erb"),
                            notify  => Service['xvfb'];
                        '/lib/systemd/system/Xsession.service':
                            content => template("${module_name}/Xsession.service.erb"),
                            notify  => Service['Xsession'];
                        '/lib/systemd/system/changeresolution.service':
                            content => template("${module_name}/changeresolution.service.erb"),
                            notify  => Service['changeresolution'];
                        '/usr/local/bin/changeresolution.sh':
                            source => 'puppet:///modules/gui/changeresolution.sh',
                            notify => Service['changeresolution'];
                    }
                    # start x11 *or* xvfb, depending on whether we have a GPU or not
                    $x11_ensure = $on_gpu ? {
                                            true    => undef,
                                            default => stopped }
                    $x11_enable = $on_gpu ? {
                                            true    => true,
                                            default => false }
                    $xvfb_ensure = $on_gpu ? {
                                            true    => stopped,
                                            default => undef }
                    $xvfb_enable = $on_gpu ? {
                                            true    => false,
                                            default => true }

                    service {
                        'x11':
                            ensure   => $x11_ensure,
                            provider => 'systemd',
                            enable   => $x11_enable,
                            require  => File['/lib/systemd/system/x11.service'],
                            notify   => Service['Xsession'];
                        'xvfb':
                            ensure   => $xvfb_ensure,
                            provider => 'systemd',
                            enable   => $xvfb_enable,
                            require  => File['/lib/systemd/system/xvfb.service'],
                            notify   => Service['Xsession'];
                        'Xsession':
                            # we do not ensure this is running; the system will start
                            # it after puppet is done
                            provider => 'systemd',
                            enable   => true,
                            require  => File['/lib/systemd/system/Xsession.service'];
                        'changeresolution':
                            # To force resolution to 1600x1200 for Intel driver, we will use a service to run some xrander
                            # commands after the Xsession service will be started
                            provider => 'systemd',
                            enable   => true,
                            require  => File['/lib/systemd/system/changeresolution.service'];
                    }
                }
                default: {
                    fail ("Cannot install on Ubuntu version ${::operatingsystemrelease}")
                }
            }
        }
        default: {
            fail("gui is not supported on ${::operatingsystem}")
        }
    }
}
