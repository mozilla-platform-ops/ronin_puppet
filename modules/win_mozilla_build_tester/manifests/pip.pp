# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_tester::pip {
  if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
    $cache_drive  = 'y:'
  } else {
    $cache_drive  = $facts['custom_win_systemdrive']
  }

  file { "${$facts['custom_win_programdata']}\\pip":
    ensure => directory,
  }
  file { "${$facts['custom_win_programdata']}\\pip\\pip.ini":
    content => file('win_mozilla_build/pip.conf'),
  }
  file { "${cache_drive}\\pip-cache":
    ensure => directory,
  }
  # Resource from puppetlabs-acl
  acl { "${cache_drive}\\pip-cache":
    target      => "${cache_drive}\\pip-cache",
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
