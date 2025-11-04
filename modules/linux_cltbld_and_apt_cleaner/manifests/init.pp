# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Class: linux_cltbld_and_apt_cleaner
# Ensures cltbld-and-apt-cleaner.sh is installed and only supports Ubuntu systems.
class linux_cltbld_and_apt_cleaner {
  include shared

  # only support ubuntu
  if $facts['os']['name'] != 'Ubuntu' {
    fail("Cannot install on ${facts['os']['name']}")
  }

  # place file
  file { '/usr/sbin/cltbld-and-apt-cleaner.sh':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => "puppet:///modules/${module_name}/cltbld-and-apt-cleaner.sh",
  }

  # Create the systemd service file
  file { '/etc/systemd/system/cltbld-cleaner.service':
    ensure  => file,
    source  => "puppet:///modules/${module_name}/cltbld-cleaner.service",
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => File['/usr/sbin/cltbld-and-apt-cleaner.sh'],
  }

  # Ensure systemd reloads the service files
  exec { 'systemd-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/cltbld-cleaner.service'],
  }

  # Enable the service to run at startup
  service { 'cltbld-cleaner':
    # don't ensure running, we want it to run once at startup
    # ensure  => 'running',
    enable  => true,
    require => Exec['systemd-reload'],
  }
}
