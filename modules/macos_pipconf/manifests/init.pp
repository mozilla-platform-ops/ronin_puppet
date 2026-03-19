# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_pipconf (
  Boolean $enabled = true,
){
  if $enabled{

      file { '/Library/Application Support/pip/':
        ensure => 'directory',
        owner  => 'root',
        group  => 'wheel',
        mode   => '0644',
            }

      file { '/Library/Application Support/pip/pip.conf':
        content => file('macos_pipconf/pip.conf'),
        owner   => 'root',
        group   => 'wheel',
        mode    => '0644',
            }
  }
}
