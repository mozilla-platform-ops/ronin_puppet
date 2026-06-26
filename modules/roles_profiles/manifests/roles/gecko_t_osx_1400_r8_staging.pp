# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::gecko_t_osx_1400_r8_staging {
  include macos_utils::disable_bluetooth_setup
  include macos_utils::always_show_scroll_bars
  include macos_utils::suppress_keyboard_assistant
  include roles_profiles::profiles::cltbld_user
  include macos_bin_signer
  include macos_directory_cleaner
  include macos_disable_firewall
  include roles_profiles::profiles::macos_fsmonitor
  include macos_gw_checker
  include macos_lsdb
  include macos_notification_disabler
  include macos_people_remover
  include macos_run_puppet
  include macos_tcc_perms
  include macos_xcode_tools
  include roles_profiles::profiles::motd
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::packages_installed
  include macos_pipconf
  include macos_power_management
  include roles_profiles::profiles::relops_users
  include roles_profiles::profiles::safaridriver
  include roles_profiles::profiles::sudo
  include roles_profiles::profiles::talos
  include roles_profiles::profiles::timezone
  include roles_profiles::profiles::users
  include roles_profiles::profiles::vnc
  include roles_profiles::profiles::worker
}
