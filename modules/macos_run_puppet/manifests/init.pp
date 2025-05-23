# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_run_puppet (
  Boolean $enabled = true,
) {
  # Deploy auto-puppet.sh to /usr/local/bin/ with execution permissions
  file { '/usr/local/bin/run-puppet.sh':
    ensure => file,
    source => 'puppet:///modules/macos_run_puppet/run-puppet.sh',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }
}
