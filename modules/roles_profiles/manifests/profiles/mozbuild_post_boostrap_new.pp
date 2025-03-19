# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mozbuild_post_boostrap_new {
  $mozbld = "C:\\mozilla-build"
  case $facts['custom_win_location'] {
    'azure': {
      $srcloc = lookup('windows.ext_pkg_src')
      if $facts['custom_win_os_arch'] != 'aarch64' {
        $cache_drive = 'd:'
      }
      else {
        $cache_drive = 'c:'
      }
    }
    'datacenter': {
      $cache_drive = 'c:'
      $srcloc       = lookup('windows.s3.ext_pkg_src')
    }
    default: {
      fail('custom_win_location not supported')
    }
  }

  file { "${cache_drive}\\hg-shared":
    ensure => directory,
  }

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

  case lookup('win-worker.function') {
    'builder': {
      file { "C:\\mozilla-build\\mozmake":
        ensure => directory,
      }
      file { "C:\\mozilla-build\\mozmake\\mozmake.exe":
        ensure => file,
        source => "${$srcloc}/mozmake.exe",
      }
      file { "C:\\mozilla-build\\builds":
        ensure => directory,
      }

      windows_env { "PATH=${mozbld}\\bin": }
      windows_env { "PATH=${mozbld}\\kdiff3": }
      windows_env { "PATH=${mozbld}\\msys2": }
      windows_env { "PATH=${mozbld}\\python3": }
      windows_env { "PATH=${mozbld}\\msys2\\usr\\bin": }
      windows_env { "PATH=${mozbld}\\mozmake": }
    }
    'tester': {
      windows_env { "PATH=${mozbld}\\bin": }
      windows_env { "PATH=${mozbld}\\kdiff3": }
      windows_env { "PATH=${mozbld}\\msys2": }
      windows_env { "PATH=${mozbld}\\python3": }
      windows_env { "PATH=${mozbld}\\msys2\\usr\\bin": }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
