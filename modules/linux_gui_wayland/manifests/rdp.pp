# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Share the logged-in worker desktop. Credentials and TLS keys are generated
# per host by the session helper and remain stable across worker reboots.
class linux_gui_wayland::rdp (
  String $builder_user,
  String $builder_group,
  String $builder_home,
) {
  package { ['gnome-remote-desktop', 'gir1.2-secret-1']:
    ensure => installed,
  }

  file {
    '/etc/systemd/user/gnome-keyring-daemon.service.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755';
    '/etc/systemd/user/gnome-keyring-daemon.service.d/10-worker-login.conf':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/linux_gui_wayland/worker-keyring.conf';
    "${builder_home}/.config/ronin-wayland-rdp":
      ensure => directory,
      owner  => $builder_user,
      group  => $builder_group,
      mode   => '0700';
    '/usr/local/bin/configure-wayland-rdp':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/linux_gui_wayland/configure-wayland-rdp.py';
    '/etc/xdg/autostart/ronin-wayland-rdp.desktop':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/linux_gui_wayland/ronin-wayland-rdp.desktop';
  }
}
