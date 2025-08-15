# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::copy_vcs_checkout_to_cache {
  $source_path = 'C:\\vcs-checkout'
  $destination_path = 'D:\\vcs-checkout'

  # Create destination directory
  file { $destination_path:
    ensure => directory,
  }

  # Move the hg-shared directory using PowerShell
  exec { 'move_hg_shared_to_cache':
    command  => "Move-Item -Path '${source_path}\\*' -Destination '${destination_path}' -Force; Remove-Item '${source_path}' -Recurse -Force",
    provider => powershell,
    onlyif   => "Test-Path '${source_path}'",
    require  => File[$destination_path],
  }

  # Set proper permissions on the directory
  acl { $destination_path:
    target      => $destination_path,
    permissions => {
      identity                   => 'everyone',
      rights                     => ['full'],
      perm_type                  => 'allow',
      child_types                => 'all',
      affects                    => 'all',
      inherit_parent_permissions => true,
    },
    require     => File[$destination_path],
  }
}
