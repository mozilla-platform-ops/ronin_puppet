# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::git {
  $detected_git_version = $facts['custom_win_git_version']

  notice("DEBUG roles_profiles::profiles::git custom_win_git_version=${detected_git_version} type=${type($detected_git_version)}")

  if ($detected_git_version == '0.0.0') {
    notice('DEBUG roles_profiles::profiles::git declaring Chocolatey git package because custom_win_git_version is 0.0.0')
    include chocolatey
    case $facts['os']['name'] {
      'Windows': {
        $git_version = lookup('windows.git.version')

        notice("DEBUG roles_profiles::profiles::git windows.git.version=${git_version}")

        package { 'git':
          ensure   => $git_version,
          provider => 'chocolatey',
        }
      }
      default: {
        fail("${$facts['os']['name']} not supported")
      }
    }
  } else {
    notice("DEBUG roles_profiles::profiles::git skipping Git package because custom_win_git_version=${detected_git_version}")
  }
}
