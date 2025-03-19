# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_auto_puppet (
  Boolean $enabled = true,
  String $puppet_role = lookup('generic_worker.gecko_t_osx_1400_r8_staging', String, 'first', 'default_role')
) {
  # Ensure /etc/facter/ exists
  file { '/etc/facter/':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Ensure /etc/facter/facts.d exists
  file { '/etc/facter/facts.d':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Set Puppet role dynamically
  file { '/etc/facter/facts.d/puppet_role.txt':
    ensure  => file,
    content => "puppet_role=${puppet_role}\n",
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
  }

  # Ensure /etc/puppet_role exists and matches Facter
  file { '/etc/puppet_role':
    ensure  => file,
    content => "${puppet_role}\n",
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
  }

  # Deploy auto-puppet.sh to /usr/local/bin/ with execution permissions
  file { '/usr/local/bin/auto-puppet.sh':
    ensure => file,
    source => 'puppet:///modules/macos_auto_puppet/auto-puppet.sh',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }
}
