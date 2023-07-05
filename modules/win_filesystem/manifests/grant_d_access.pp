# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::grant_d_access {
  if $facts['custom_win_d_drive'] == 'exists' {
    acl { 'D:':
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
