# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# USN-8928-1: update the OpenSSH client, server and SFTP server on Ubuntu 24.04.
class linux_packages::openssh {
  exec { 'apt_update_for_openssh':
    command => '/usr/bin/apt-get update',
    unless  => "/usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' openssh-client)\" ge 1:9.6p1-3ubuntu13.20 && /usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' openssh-server)\" ge 1:9.6p1-3ubuntu13.20 && /usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' openssh-sftp-server)\" ge 1:9.6p1-3ubuntu13.20",
    timeout => 600,
  }

  package { ['openssh-client', 'openssh-server', 'openssh-sftp-server']:
    ensure   => '>=1:9.6p1-3ubuntu13.20',
    provider => 'apt',
    require  => Exec['apt_update_for_openssh'],
  }
}
