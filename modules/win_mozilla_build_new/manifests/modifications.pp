# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_new::modifications {
  $mozbld      = "C:\\mozilla-build"

  file { "${mozbld}\\python\\Scripts\\hg":
    ensure => absent,
    purge  => true,
    force  => true,
  }

  # Resource from counsyl-windows
  windows::environment { 'MOZILLABUILD':
    value => $mozbld,
  }
  # Resource from counsyl-windows
  windows_env { "PATH=${mozbld}\\bin": }
  windows_env { "PATH=${mozbld}\\kdiff": }
  windows_env { "PATH=${mozbld}\\msys2": }
  windows_env { "PATH=${mozbld}\\python3": }
  windows_env { "PATH=${mozbld}\\mozmake": }
  windows_env { "PATH=${mozbld}\\msys2\\usr\\bin": }

  exec { 'set_path':
    command  => file('win_mozilla_build/set_path.ps1.'),
    provider => powershell,
  }
}
