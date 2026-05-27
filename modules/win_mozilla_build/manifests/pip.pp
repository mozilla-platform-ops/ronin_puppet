# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::pip {
  case $facts['custom_win_location'] {
    'azure': {
      if $facts['custom_win_d_drive'] == 'exists' {
        $cache_drive = 'D:'
      } else {
        $cache_drive = 'C:'
      }
    }
    'datacenter': {
      $cache_drive = 'C:'
    }
    default: {
      fail('custom_win_location not supported')
    }
  }
  $win_worker_function = lookup('win-worker.function', { 'default_value' => undef })
  $is_azure_temp_drive = ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_d_drive'] == 'exists')
  $configure_azure_temp_drive = $is_azure_temp_drive and ($win_worker_function in ['builder', 'tester'])
  if $configure_azure_temp_drive {
    include win_filesystem::configure_nvme_disk
    $azure_temp_drive_require = Class['win_filesystem::configure_nvme_disk']
  } else {
    $azure_temp_drive_require = undef
  }

  file { "${$facts['custom_win_programdata']}\\pip":
    ensure => directory,
  }
  file { "${$facts['custom_win_programdata']}\\pip\\pip.ini":
    content => epp('win_mozilla_build/pip.conf.epp'),
  }
  file { "${cache_drive}\\pip-cache":
    ensure  => directory,
    require => $azure_temp_drive_require,
  }
  # Resource from puppetlabs-acl
  acl { "${cache_drive}\\pip-cache":
    target      => "${cache_drive}\\pip-cache",
    require     => File["${cache_drive}\\pip-cache"],
    permissions => {
      identity                   => 'everyone',
      rights                     => ['full'],
      perm_type                  => 'allow',
      child_types                => 'all',
      affects                    => 'all',
      inherit_parent_permissions => true,
    },
  }
  # Resource from counsyl-windows
  windows::environment { 'PIP_DOWNLOAD_CACHE':
    value => "${cache_drive}\\pip-cache",
  }
}
