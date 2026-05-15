# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs mozilla build
class roles_profiles::profiles::mozilla_build {
  case $facts['custom_win_bootstrap_stage'] {
    'complete': {
      include win_mozilla_build::pip
      include win_mozilla_build::hg_files
    }
    default: {
      $srcloc  = lookup('windows.ext_pkg_src')
      $version = lookup('windows.mozilla_build.version')
      class { 'win_mozilla_build::install':
        version => $version,
        srcloc  => $srcloc,
      }
      class { 'win_mozilla_build::grant_symlink_access':
        srcloc => $srcloc,
      }
      include win_mozilla_build::modifications
      include win_mozilla_build::install_py3_certs
      include win_mozilla_build::tooltool
      include win_mozilla_build::hg_files
      include win_mozilla_build::install_psutil
      include win_mozilla_build::install_zstandard
      include win_mozilla_build::pip
    }
  }
}
