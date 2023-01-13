# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::grant_z_access {
  if $facts['custom_win_z_drive'] == 'exists' {
    acl { 'Z:':
      permissions                => {
        identity    => 'everyone',
        rights      => ['full'],
        perm_type   => 'allow',
        child_types => 'all',
        affects     => 'all',
      },
    }
  }
}
