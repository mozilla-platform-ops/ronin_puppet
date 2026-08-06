# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs the local host-lifecycle event logger and its durable storage.
class linux_host_lifecycle {
  package { 'logrotate':
    ensure => installed,
  }

  file {
    default:
      owner => 'root',
      group => 'root',
      mode  => '0644';

    '/usr/local/bin/lifecycle-log':
      ensure => file,
      source => "puppet:///modules/${module_name}/lifecycle-log",
      mode   => '0755';

    '/var/log/host-lifecycle':
      ensure => directory,
      group  => 'cltbld',
      mode   => '0775';

    '/var/log/host-lifecycle/events.jsonl':
      ensure  => file,
      group   => 'cltbld',
      mode    => '0664',
      require => File['/var/log/host-lifecycle'];

    '/etc/logrotate.d/host-lifecycle':
      ensure  => file,
      source  => "puppet:///modules/${module_name}/host-lifecycle.logrotate",
      require => Package['logrotate'];
  }

  sudo::customfile { 'lifecycle-log-import':
    content => 'cltbld ALL=(root) NOPASSWD: /usr/local/bin/lifecycle-log import-generic-worker\n',
  }
}
