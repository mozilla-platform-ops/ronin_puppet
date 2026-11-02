# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# USN-8932-1: update curl and both libcurl runtime variants on Ubuntu 24.04.
class linux_packages::curl {
  exec { 'apt_update_for_curl':
    command => '/usr/bin/apt-get update',
    unless  => "/usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' curl)\" ge 8.5.0-2ubuntu10.16 && /usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' libcurl4t64)\" ge 8.5.0-2ubuntu10.16 && /usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' libcurl3t64-gnutls)\" ge 8.5.0-2ubuntu10.16",
    timeout => 600,
  }

  package { ['curl', 'libcurl4t64', 'libcurl3t64-gnutls']:
    ensure   => '>=8.5.0-2ubuntu10.16',
    provider => 'apt',
    require  => Exec['apt_update_for_curl'],
  }
}
