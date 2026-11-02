# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# USN-8945-1: fix decoder memory handling in XZ and its shared library on Ubuntu 24.04.
class linux_packages::xz_utils {
  exec { 'apt_update_for_xz_utils':
    command => '/usr/bin/apt-get update',
    unless  => "/usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' xz-utils)\" ge 5.6.1+really5.4.5-1ubuntu0.4 && /usr/bin/dpkg --compare-versions \"$(/usr/bin/dpkg-query --show --showformat='\${Version}' liblzma5)\" ge 5.6.1+really5.4.5-1ubuntu0.4",
    timeout => 600,
  }

  package { ['xz-utils', 'liblzma5']:
    ensure   => '>=5.6.1+really5.4.5-1ubuntu0.4',
    provider => 'apt',
    require  => Exec['apt_update_for_xz_utils'],
  }
}
