# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Present an Intel output without a monitor before GDM probes the graphics cards.
class linux_gui_wayland::headless (
  Pattern[/\A(?:HDMI-A|DP|DVI-D)-[1-9][0-9]*\z/] $connector,
) {
  file {
    '/usr/local/share/ronin-wayland':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755';
    '/usr/local/share/ronin-wayland/edid.bin':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/linux_gui/edid.bin';
    '/usr/local/sbin/configure-headless-wayland':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/linux_gui_wayland/configure-headless-wayland.sh';
    '/etc/ronin-wayland-connector':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "${connector}\n";
    '/etc/systemd/system/ronin-wayland-display.service':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/linux_gui_wayland/headless-display.service',
      notify => Exec['reload systemd for headless Wayland'];
    '/etc/systemd/system/gdm3.service.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755';
    '/etc/systemd/system/gdm3.service.d/10-headless-display.conf':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/linux_gui_wayland/gdm3-headless.conf',
      notify => Exec['reload systemd for headless Wayland'];
    '/etc/udev/rules.d/61-ronin-wayland-intel.rules':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/linux_gui_wayland/61-ronin-wayland-intel.rules',
      notify => Exec['reload udev for headless Wayland'];
  }

  exec { 'reload systemd for headless Wayland':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  exec { 'reload udev for headless Wayland':
    command     => '/usr/bin/udevadm control --reload-rules && /usr/bin/udevadm trigger --subsystem-match=drm --action=change',
    provider    => 'shell',
    onlyif      => '/usr/bin/test -S /run/udev/control',
    refreshonly => true,
  }

  service { 'ronin-wayland-display':
    enable  => true,
    require => [
      Exec['reload systemd for headless Wayland'],
      Exec['reload udev for headless Wayland'],
      File['/usr/local/share/ronin-wayland/edid.bin'],
      File['/usr/local/sbin/configure-headless-wayland'],
      File['/etc/ronin-wayland-connector'],
    ],
  }

  # Docker has no Intel DRM device; validate files and boot ordering there.
  unless $facts['running_in_test_kitchen'] in [true, 'true'] {
    Service['ronin-wayland-display'] {
      ensure    => running,
      subscribe => [
        File['/usr/local/share/ronin-wayland/edid.bin'],
        File['/usr/local/sbin/configure-headless-wayland'],
        File['/etc/ronin-wayland-connector'],
        File['/etc/systemd/system/ronin-wayland-display.service'],
      ],
    }
  }
}
