# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs mozilla build
class roles_profiles::profiles::mozilla_build_new {
  include win_mozilla_build_new::install
  include win_mozilla_build_new::hg_install
  include win_mozilla_build_new::install_psutil
  include win_mozilla_build_new::install_zstandard
  include win_mozilla_build_new::install_py3_certs
}
