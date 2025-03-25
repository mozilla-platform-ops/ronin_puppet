# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_new::hg_files {
  require win_mozilla_build_new::install

  $mozbld      = "${facts['custom_win_systemdrive']}\\mozilla-build"
  $msys_dir = "${facts['custom_win_systemdrive']}\\mozilla-build\\msys2"

  ## If Azure, then cache drive is either Y or D

  case $facts['custom_win_location'] {
    'azure': {
      if $facts['custom_win_os_arch'] != 'aarch64' {
        $cache_drive = 'd:'
      }
      else {
        $cache_drive = 'c:'
      }
    }
    'datacenter': {
      $cache_drive = 'c:'
    }
    default: {
      fail('custom_win_location not supported')
    }
  }

  file { "${cache_drive}\\hg-shared":
    ensure => directory,
  }
  # Resource from counsyl-windows
  windows::environment { 'HG_CACHE':
    value => "${cache_drive}\\hg-cache",
  }
  # Reference  https://bugzilla.mozilla.org/show_bug.cgi?id=1305485#c5
  file { "${mozbld}\\robustcheckout.py":
    content => file('win_mozilla_build_new/robustcheckout.py'),
  }
  file { "${msys_dir}\\etc\\cacert.pem":
    content => file('win_mozilla_build_new/cacert.pem'),
  }
  file { "${facts['custom_win_programfiles']}\\mercurial\\mercurial.ini":
    content => file('win_mozilla_build_new/mercurial.ini'),
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
