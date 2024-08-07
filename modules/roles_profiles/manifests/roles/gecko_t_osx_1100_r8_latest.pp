# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::gecko_t_osx_1100_r8_latest {
  include macos_utils::disable_bluetooth_setup
  include roles_profiles::profiles::cltbld_user
  include roles_profiles::profiles::macos_people_remover
  include roles_profiles::profiles::macos_tcc_perms
  include roles_profiles::profiles::metrics
  include roles_profiles::profiles::motd
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::packages_installed
  include roles_profiles::profiles::pipconf
  include roles_profiles::profiles::relops_users
  include roles_profiles::profiles::safaridriver
  include roles_profiles::profiles::sudo
  include roles_profiles::profiles::timezone
  include roles_profiles::profiles::users
  include roles_profiles::profiles::vnc
  include roles_profiles::profiles::worker
}
