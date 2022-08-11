# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::git (
  String $needed_version,
  String $pkg_source,
  String $local_dir,
  String $current_version
) {
  if ($needed_version != $current_version) {
    $pkg       = "Git-${needed_version}-64-bit.exe"
    $local_pkg = "${local_dir}\\${pkg}"

    file { $local_pkg:
      source => "${pkg_source}/${pkg}",
    }
    exec { 'install_git':
      command => "${local_pkg} /silent /norestart",
    }
  }
}
