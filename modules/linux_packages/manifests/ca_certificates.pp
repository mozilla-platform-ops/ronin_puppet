# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Remove trust in the compromised eMudhra CA from the system and NSS stores on Ubuntu 24.04.
class linux_packages::ca_certificates {
  # Refresh stale package lists before upgrading an affected host.
  exec { 'apt_update_for_ca_certificates':
    command => '/usr/bin/apt-get update',
    unless  => "/usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' ca-certificates)\" ge 20260816ubuntu0.24.04.1 && /usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' libnss3)\" ge 2:3.98-1ubuntu0.3",
    timeout => 600,
  }

  # Accept newer releases without downgrading or requiring this version forever.
  package { 'ca-certificates':
    ensure   => '>=20260816ubuntu0.24.04.1',
    provider => 'apt',
    require  => Exec['apt_update_for_ca_certificates'],
  }

  # USN-8947-1: NSS ships a separate CA trust store.
  package { 'libnss3':
    ensure   => '>=2:3.98-1ubuntu0.3',
    provider => 'apt',
    require  => Exec['apt_update_for_ca_certificates'],
  }
}
