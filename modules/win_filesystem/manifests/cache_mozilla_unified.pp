# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::cache_mozilla_unified {
  $cache_drive  = $facts['custom_win_systemdrive']
  $checkout_path = "${cache_drive}\\mozilla-unified"
  $mozilla_unified_url = 'https://hg.mozilla.org/mozilla-unified'
  
  # Create the checkout directory
  file { $checkout_path:
    ensure => directory,
  }

  # Set permissions on the checkout directory (initial)
  acl { 'mozilla_unified_checkout_initial_perms':
    target      => $checkout_path,
    permissions => {
      identity                   => 'everyone',
      rights                     => ['full'],
      perm_type                  => 'allow',
      child_types                => 'all',
      affects                    => 'all',
      inherit_parent_permissions => true,
    },
    require => File[$checkout_path],
  }

  # Perform the full hg clone
  exec { 'clone_mozilla_unified':
    command => "hg clone ${mozilla_unified_url} ${checkout_path}",
    creates => "${checkout_path}\\.hg",  # Only run if .hg directory doesn't exist
    timeout => 3600,  # 1 hour timeout for large clone
    require => [File[$checkout_path], Acl["${checkout_path}_initial"]],
  }

  # Ensure permissions are applied to all files after clone
  acl { $checkout_path:
    target      => $checkout_path,
    permissions => {
      identity                   => 'everyone',
      rights                     => ['full'],
      perm_type                  => 'allow',
      child_types                => 'all',
      affects                    => 'all',
      inherit_parent_permissions => true,
    },
    require => Exec['clone_mozilla_unified'],
  }

  # Set the VCS_CHECKOUT environment variable
  windows_env { 'VCS_CHECKOUT':
    ensure    => present,
    variable  => 'VCS_CHECKOUT',
    value     => $checkout_path,
    mergemode => clobber,
    require   => [Exec['clone_mozilla_unified'], Acl[$checkout_path]],
  }
}
