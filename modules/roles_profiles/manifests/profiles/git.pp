# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::git {
  case $facts['os']['name'] {
    'Windows': {
      $minimum_version = lookup('windows.git.version')
      $detected_version = $facts['custom_win_git_version']
      if $detected_version in [undef, '0.0.0'] or versioncmp($detected_version, $minimum_version) < 0 {
        class { 'win_packages::git':
          version => $minimum_version,
        }
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
