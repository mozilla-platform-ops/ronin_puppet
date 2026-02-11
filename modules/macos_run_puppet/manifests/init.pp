# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_run_puppet (
  Boolean $enabled = true,
) {
  if $enabled {
    # place shell functions file that has metadata genration code
    # - linux uses /etc/puppet/lib, use /opt/puppet_environments/lib/ instead on macOS
    file { '/opt/puppet_environments/lib':
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    file { '/opt/puppet_environments/lib/puppet_state_functions.sh':
      ensure => file,
      source => "puppet:///modules/${module_name}/puppet_state_functions.sh",
      owner  => 'root',
      group  => 'wheel',
      mode   => '0644',
    }

    file { '/usr/local/bin/run-puppet.sh':
      ensure => file,
      source => 'puppet:///modules/macos_run_puppet/run-puppet.sh',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }
  }
}
