# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## CLEAN UP: lookups should be in the profile and passed to this class.

class win_mozilla_build::modifications {
  require win_mozilla_build::install

  $mozbld = "C:\\mozilla-build"
  $srcloc = lookup('windows.ext_pkg_src')

  windows::environment { 'MOZILLABUILD':
    value => $mozbld,
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

      exec { 'setmsys2path':
        command  => file('win_mozilla_build/set_path.ps1'),
        provider => powershell,
      }
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
