# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::staging {
  $path = "${facts['custom_win_systemdrive']}\\RoninPackages"

  file { $path:
    ensure  => directory,
    recurse => true,
    purge   => true,
    force   => true,
    backup  => false,
  }
  acl { $path:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => File[$path],
  }
}
