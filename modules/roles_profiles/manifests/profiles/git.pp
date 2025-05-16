# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::git {
  if ($facts['custom_win_git_version'] == '0.0.0') {
    include chocolatey
    case $facts['os']['name'] {
      'Windows': {
        $git_version = lookup('windows.git.version')

        package { 'git':
          ensure   => $git_version,
          provider => 'chocolatey',
        }
      }
      default: {
        fail("${$facts['os']['name']} not supported")
      }
    }
  }
}
