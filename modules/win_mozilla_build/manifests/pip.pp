# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::pip {
  file { "${$facts['custom_win_programdata']}\\pip":
    ensure => directory,
  }
  file { "${$facts['custom_win_programdata']}\\pip\\pip.ini":
    content => epp('win_mozilla_build/pip.conf.epp'),
  }

  file { ['C:\\pip-cache', 'D:\\pip-cache']:
    ensure => absent,
    force  => true,
  }

  windows::environment { 'PIP_DOWNLOAD_CACHE':
    ensure => absent,
  }
}
