# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_gui_wayland (
  String $builder_user,
  String $builder_group,
  String $builder_home,
  Optional[Pattern[/\A(?:HDMI-A|DP|DVI-D)-[1-9][0-9]*\z/]] $headless_connector = undef,
) {
  class { 'linux_gui':
    builder_user  => $builder_user,
    builder_group => $builder_group,
    builder_home  => $builder_home,
    session_type  => 'wayland',
  }

  class { 'linux_gui_wayland::rdp':
    builder_user  => $builder_user,
    builder_group => $builder_group,
    builder_home  => $builder_home,
  }
  Class['linux_gui_wayland::rdp'] -> Service['gdm3']

  if $headless_connector {
    class { 'linux_gui_wayland::headless':
      connector => $headless_connector,
    }
    Class['linux_gui_wayland::headless'] -> Service['gdm3']
  }

  # Select the worker session without replacing other AccountsService settings.
  file { "/var/lib/AccountsService/users/${builder_user}":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => Class['linux_gui'],
  }

  ini_setting { 'worker Wayland session':
    ensure  => present,
    path    => "/var/lib/AccountsService/users/${builder_user}",
    section => 'User',
    setting => 'Session',
    value   => 'ubuntu',
    require => File["/var/lib/AccountsService/users/${builder_user}"],
  }
  ini_setting { 'worker Wayland session type':
    ensure  => present,
    path    => "/var/lib/AccountsService/users/${builder_user}",
    section => 'User',
    setting => 'SessionType',
    value   => 'wayland',
    require => Ini_setting['worker Wayland session'],
  }

  package { 'python3-gi':
    ensure => installed,
  }

  exec { 'boot to Wayland desktop':
    command => '/usr/bin/systemctl set-default graphical.target',
    unless  => '/usr/bin/test /etc/systemd/system/default.target -ef /lib/systemd/system/graphical.target',
    require => Class['linux_gui'],
  }

  file { '/usr/local/bin/start-wayland-worker':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => "puppet:///modules/${module_name}/start-wayland-worker.py",
  }
}
