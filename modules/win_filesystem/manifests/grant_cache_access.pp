# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::grant_cache_access (
  Optional[String] $cache_drive = undef,
) {
  if $cache_drive {
    $_cache_drive = $cache_drive
  } elsif ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
    ## 2012 r2 still uses y: for the cache drive
    case $facts['custom_win_os_version'] {
      'win_2012': {
        $_cache_drive = 'Y:'
      }
      default: {
        $_cache_drive = 'D:'
      }
    }
  } else {
    $_cache_drive = $facts['custom_win_systemdrive']
  }
  $win_worker_function = lookup('win-worker.function', { 'default_value' => undef })
  $is_azure_temp_drive = ($facts['custom_win_location'] == 'azure') and ($_cache_drive == 'D:')
  $configure_azure_temp_drive = $is_azure_temp_drive and ($win_worker_function in ['builder', 'tester'])
  if $configure_azure_temp_drive {
    include win_filesystem::configure_nvme_disk
    $azure_temp_drive_require = Class['win_filesystem::configure_nvme_disk']
  } else {
    $azure_temp_drive_require = undef
  }

  # Resource from puppetlabs-acl
  acl { "${_cache_drive}\\hg-shared":
    target      => "${_cache_drive}\\hg-shared",
    require     => $azure_temp_drive_require,
    permissions => {
      identity                   => 'everyone',
      rights                     => ['full'],
      perm_type                  => 'allow',
      child_types                => 'all',
      affects                    => 'all',
      inherit_parent_permissions => true,
    },
  }

  File <| title == "${_cache_drive}\\hg-shared" |> -> Acl["${_cache_drive}\\hg-shared"]
}
