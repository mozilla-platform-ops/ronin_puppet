# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs mozilla build
class roles_profiles::profiles::mozilla_build_new {
  case $facts['custom_win_bootstrap_stage'] {
    'complete': {
      include win_mozilla_build_new::pip
      include win_mozilla_build_new::hg_files
    }
    default: {
      include win_mozilla_build_new::install
      include win_mozilla_build_new::modifications
      include win_mozilla_build_new::install_py3_certs
      include win_mozilla_build_new::tooltool
      include win_mozilla_build_new::hg_files
      include win_mozilla_build_new::grant_symlink_access
      include win_mozilla_build_new::install_psutil
      include win_mozilla_build_new::install_zstandard
      include win_mozilla_build_new::pip
    }
  }
}
