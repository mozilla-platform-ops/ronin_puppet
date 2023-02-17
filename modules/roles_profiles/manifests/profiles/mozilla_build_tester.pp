# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs mozilla build
class roles_profiles::profiles::mozilla_build_tester {
  include win_mozilla_build_tester::install
  include win_mozilla_build_tester::modifications
  include win_mozilla_build_tester::hg_install
  include win_mozilla_build_tester::hg_files
  include win_mozilla_build_tester::install_psutil
  include win_mozilla_build_tester::install_zstandard
  include win_mozilla_build_tester::install_py3_certs
}
