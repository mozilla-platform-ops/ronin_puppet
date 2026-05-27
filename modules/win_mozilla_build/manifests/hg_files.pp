# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::hg_files {
  require win_mozilla_build::install

  $mozbld      = "${facts['custom_win_systemdrive']}\\mozilla-build"
  $msys_dir = "${facts['custom_win_systemdrive']}\\mozilla-build\\msys2"
  $win_worker_function = lookup('win-worker.function', { 'default_value' => undef })
  $configure_azure_temp_drive = ($facts['custom_win_location'] == 'azure') and ($win_worker_function in ['builder', 'tester'])

  ## If Azure, then cache drive is either Y or D

  case $facts['custom_win_location'] {
    'azure': {
      if ($facts['custom_win_d_drive'] == 'exists') or $configure_azure_temp_drive {
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
  if $configure_azure_temp_drive {
    include win_filesystem::configure_nvme_disk
    $azure_temp_drive_require = Class['win_filesystem::configure_nvme_disk']
  } else {
    $azure_temp_drive_require = undef
  }

  file { "${cache_drive}\\hg-shared":
    ensure  => directory,
    require => $azure_temp_drive_require,
  }
  # Resource from counsyl-windows
  windows::environment { 'HG_CACHE':
    value => "${cache_drive}\\hg-cache",
  }
  # Reference  https://bugzilla.mozilla.org/show_bug.cgi?id=1305485#c5
  file { "${mozbld}\\robustcheckout.py":
    content => file('win_mozilla_build/robustcheckout.py'),
  }
  file { "${facts['custom_win_programfiles']}\\mercurial\\mercurial.ini":
    content => file('win_mozilla_build/mercurial.ini'),
  }
  # Resource from puppetlabs-acl
  acl { "${cache_drive}\\hg-shared":
    target      => "${cache_drive}\\hg-shared",
    require     => File["${cache_drive}\\hg-shared"],
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
