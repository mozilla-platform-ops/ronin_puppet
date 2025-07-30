# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# for x11, see linux_gui_wayland for wayland

class linux_gui (
  $builder_user,
  $builder_group,
  $builder_home
) {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04': {
          # used in templates
          $screen_width  = 1600
          $screen_height = 1200
          $screen_depth  = 32
          $refresh       = 60

          # The new moonshot hardware GPU workers have an intel gpu.
          $use_nvidia = false
          $on_gpu = true

          # Remove the nvidia packages so they do not conflict with intel.
          package {
            'nvidia-*':
              ensure => absent;
          }

          include linux_gui::appearance

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

            # bug 984944: jockey is gone in 18.04
            # Bug 984944: deja-dup-monitor prevents taking screenshots
            '/etc/xdg/autostart/org.gnome.DejaDup.Monitor.desktop':
              source => "puppet:///modules/${module_name}/org.gnome.DejaDup.Monitor.desktop";

            # disable update-notifer
            '/etc/xdg/autostart/update-notifier.desktop':
              source => "puppet:///modules/${module_name}/update-notifier.desktop";

            # from 1804 docker image
            # see https://searchfox.org/mozilla-central/source/taskcluster/docker/ubuntu1804-test/autostart/gnome-software-service.desktop
            # Bug 1345105 - Do not run periodical update checks and downloads
            '/etc/xdg/autostart/gnome-software-service.desktop':
              source => "puppet:///modules/${module_name}/gnome-software-service.desktop";

            # from 1804 docker image
            # # Bug 1638183 - increase xserver maximum client count
            '/usr/share/X11/xorg.conf.d/99-serverflags.conf':
              source => "puppet:///modules/${module_name}/99-serverflags.conf";

            "${builder_home}/.xsessionrc":
              content => "DESKTOP_SESSION=ubuntu\n",
              owner   => $builder_user,
              group   => $builder_group,
              mode    => '0644',
              notify  => Service['x11'];

            # make sure the builder user doesn't have any funny business
            ["${builder_home}/.xsession",
              "${builder_home}/.xinitrc",
            "${builder_home}/.Xsession"]:
              ensure => absent;

            # from 1804 docker image
            # Disable font antialiasing for now to match releng's setup
            "${builder_home}/.fonts.conf":
              owner  => $builder_user,
              group  => $builder_group,
              mode   => '0644',
              source => "puppet:///modules/${module_name}/fonts.conf";

            # from 1804 docker image
            # silence pip version warnings
            # TODO: should be in linux base
            # RELOPS-1318: We used to disable autospawn in client.conf, but may be causing issues. Removed this in relops-1318.
            ["${builder_home}/.pip",
            "${builder_home}/.config/pulse"]:
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

          # RELOPS-1318: Let's make sure pulse client.conf is not present
          file { "${builder_home}/.config/pulse/client.conf":
            ensure => absent,
          }

          # disable gdm (we run our own X server)
          exec { 'set systemctl default to multi-user vs graphical':
            command  => 'systemctl set-default multi-user.target',
            onlyif   => 'if [[ `systemctl get-default` == "multi-user.target" ]]; then exit 1 ; else exit 0; fi;',
            path     => ['/bin'],
            provider => 'shell',
          }

          $gpu_bus_id = 'PCI:0:02:0'
          file {
            '/etc/X11/xorg.conf':
              ensure  => file,
              content => template("${module_name}/xorg.conf.erb"),
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
              source => 'puppet:///modules/linux_gui/changeresolution.sh',
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
        '24.04': {
          include linux_gui::appearance

          # install the window manager and its prereqs
          # done in roles_profiles::profiles::gui

          # and the latest version of gnome-settings-daemon; older versions crash
          # (Bug 846348)
          include linux_packages::gnome_settings_daemon
          # Bug 859972: xrestop is needed for talos data collection
          include linux_packages::xrestop

          # used in templates
          $screen_width  = 1600
          $screen_height = 1200
          $screen_depth  = 32
          $refresh       = 60
          # TODO?: use puppetlabs-stdlib eventually
          $builder_uid = generate('/usr/bin/id', '-u', $builder_user)
          $builder_gid = generate('/usr/bin/id', '-g', $builder_user)

          # The new moonshot hardware GPU workers have an intel gpu.
          $use_nvidia = false
          $on_gpu = true

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

            # bug 984944: jockey is gone in 18.04
            # Bug 984944: deja-dup-monitor prevents taking screenshots
            '/etc/xdg/autostart/org.gnome.DejaDup.Monitor.desktop':
              source => "puppet:///modules/${module_name}/org.gnome.DejaDup.Monitor.desktop";

            # disable update-notifer
            '/etc/xdg/autostart/update-notifier.desktop':
              source => "puppet:///modules/${module_name}/update-notifier.desktop";

            # from 1804 docker image
            # see https://searchfox.org/mozilla-central/source/taskcluster/docker/ubuntu1804-test/autostart/gnome-software-service.desktop
            # Bug 1345105 - Do not run periodical update checks and downloads
            '/etc/xdg/autostart/gnome-software-service.desktop':
              source => "puppet:///modules/${module_name}/gnome-software-service.desktop";

            # from 1804 docker image
            # # Bug 1638183 - increase xserver maximum client count
            '/usr/share/X11/xorg.conf.d/99-serverflags.conf':
              source => "puppet:///modules/${module_name}/99-serverflags.conf";

            "${builder_home}/.xsessionrc":
              content => "DESKTOP_SESSION=ubuntu\n",
              owner   => $builder_user,
              group   => $builder_group,
              mode    => '0644',
              notify  => Service['x11'];

            # make sure the builder user doesn't have any funny business
            ["${builder_home}/.xsession",
              "${builder_home}/.xinitrc",
            "${builder_home}/.Xsession"]:
              ensure => absent;

            # from 1804 docker image
            # Disable font antialiasing for now to match releng's setup
            "${builder_home}/.fonts.conf":
              owner  => $builder_user,
              group  => $builder_group,
              mode   => '0644',
              source => "puppet:///modules/${module_name}/fonts.conf";

            # from 1804 docker image
            # silence pip version warnings
            # TODO: should be in linux base
            # RELOPS-1318: We used to disable autospawn in client.conf, but may be causing issues. Removed this in relops-1318.
            ["${builder_home}/.pip",
            "${builder_home}/.config/pulse"]:
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

          # RELOPS-1318: Let's make sure pulse client.conf is not present
          file { "${builder_home}/.config/pulse/client.conf":
            ensure => absent,
          }

          # disable gdm (we run our own X server)
          exec { 'set systemctl default to multi-user vs graphical':
            command  => 'systemctl set-default multi-user.target',
            onlyif   => 'if [[ `systemctl get-default` == "multi-user.target" ]]; then exit 1 ; else exit 0; fi;',
            path     => ['/bin'],
            provider => 'shell',
          }

          $gpu_bus_id = 'PCI:0:02:0'
          file {
            '/etc/X11/xorg.conf':
              ensure  => file,
              content => template("${module_name}/xorg.conf.erb"),
              notify  => Service['x11'];
            '/lib/systemd/system/x11.service':
              content => template("${module_name}/x11.service.erb"),
              notify  => Service['x11'];
            '/lib/systemd/system/xvfb.service':
              content => template("${module_name}/xvfb.service.erb"),
              notify  => Service['xvfb'];
            '/lib/systemd/system/Xsession.service':
              content => template("${module_name}/Xsession.service_2404.erb"),
              notify  => Service['Xsession'];
            '/lib/systemd/system/changeresolution.service':
              content => template("${module_name}/changeresolution.service.erb"),
              notify  => Service['changeresolution'];
            '/usr/local/bin/changeresolution.sh':
              source => 'puppet:///modules/linux_gui/changeresolution.sh',
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

          # Remove the nvidia packages so they do not conflict with intel.
          package {
            'nvidia-*':
              ensure => absent;
          }

          # TODO: rest goes here

          # TODO: force to x11 from wayland
          # info('Forcing X11 for Ubuntu 24.04')

          # # TODO: we don't run gdm, so this does nothiing. our systemd target disables it.
          # # /etc/gdm3/custom.conf: used to disable Wayland
          # file { '/etc/gdm3/custom.conf':
          #   owner  => 'root',
          #   group  => 'root',
          #   mode   => '0644',
          #   source => "puppet:///modules/${module_name}/gdm3-custom.conf",
          #   # notify => Service['gdm3'];
          # }

          # packages to remove
          # sudo apt remove --autoremove gnome-initial-setup
          # about:
          #   gnome-initial-setup: popus up first-start dialog
          $remove_packages = ['gnome-initial-setup']
          package { $remove_packages:
            ensure => absent,
          }

          # debugging systemd-networkd-wait-online hanging during boot...
          # `Ubuntu can use either systemd-networkd (default on servers) or NetworkManager (default on desktops) to manage networking.`
          #   see https://askubuntu.com/questions/1217252/boot-process-hangs-at-systemd-networkd-wait-online
          #
          # export SYSTEMD_LOG_LEVEL=debug
          # networkctl

          # TODO: copy this to the wayland config (or pull out into a 2404 specific class)
          # having two subsystems managing the network is not a good idea... disable systemd-networkd
          #
          # systemctl disable systemd-networkd.service
          exec { 'disable systemd-networkd':
            command  => 'systemctl disable systemd-networkd.service',
            onlyif   => 'systemctl is-active systemd-networkd.service',
            path     => ['/bin'],
            provider => 'shell',
          }

          # allow builder user to linger (allows `systemd --user` services to work without a login)
          exec { "enable-linger-${builder_user}":
            command => "/usr/bin/loginctl enable-linger ${builder_user}",
            unless  => "/usr/bin/loginctl show-user ${builder_user} | grep -q 'Linger=yes'",
            path    => ['/usr/bin', '/bin'],
          }

          # ensure ~/.config/systemd/user/ exists
          file { [
              "${builder_home}/.config/systemd",
              "${builder_home}/.config/systemd/user",
            ]:
              ensure => directory,
              owner  => $builder_user,
              group  => $builder_group,
              mode   => '0755',
          }

          # add a builder-user gnome-session service
          file { "${builder_home}/.config/systemd/user/gnome-session-x11.service":
            ensure  => file,
            owner   => $builder_user,
            group   => $builder_group,
            mode    => '0644',
            content => template("${module_name}/gnome-session-x11.service.erb"),
            require => Exec["enable-linger-${builder_user}"],
          }

          # the enablement script does:
          #   reload the user systemd daemon
          #   enable and start the user service
          #
          # for some reason the commands need to be run rapidly after each other to work

          # place enablement script
          file { '/usr/local/bin/enable-gnome-session-x11-service.sh':
            ensure => file,
            owner  => $builder_user,
            group  => $builder_group,
            mode   => '0755',
            source => "puppet:///modules/${module_name}/enable_gnome_session_x11_service.sh",
          }

          # run enablement script
          exec { 'run-enable-gnome-session-x11-service':
            command => "sudo -u ${builder_user} enable-gnome-session-x11-service.sh",
            path    => ['/usr/bin', '/bin', '/usr/sbin', '/sbin', '/usr/local/bin'],
            require => File['/usr/local/bin/enable-gnome-session-x11-service.sh'],
          }
        }
        default: {
          fail ("Cannot install on Ubuntu version ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("gui is not supported on ${facts['os']['name']}")
    }
  }
}
