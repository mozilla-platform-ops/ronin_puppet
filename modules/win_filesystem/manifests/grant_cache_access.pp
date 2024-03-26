# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::grant_cache_access {
  if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
    $cache_drive  = 'D:'
  } else {
    $cache_drive  = $facts['custom_win_systemdrive']
  }

  # Resource from puppetlabs-acl
  acl { "${cache_drive}\\hg-shared":
    target      => "${cache_drive}\\hg-shared",
    permissions => {
      identity                   => 'everyone',
      rights                     => ['full'],
      perm_type                  => 'allow',
      child_types                => 'all',
      affects                    => 'all',
      inherit_parent_permissions => true,
    },
  }
}
