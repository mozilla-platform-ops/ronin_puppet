# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Dedicated role for an M4 mini repurposed as the on-network reprovision-runner
# host (e.g. macmini-m4-81, off-CI). It is NOT a CI worker: no generic-worker,
# talos, screenshot helper, etc. It carries the base OS/user/management profiles
# plus the reprovision_runner profile.
class roles_profiles::roles::gecko_t_osx_1500_m4_reprovision_runner {
  # base OS niceties (harmless, shared with the CI m4 role)
  include macos_utils::disable_bluetooth_setup
  include macos_utils::always_show_scroll_bars
  include macos_utils::suppress_keyboard_assistant

  # access + management
  include roles_profiles::profiles::relops_users
  include roles_profiles::profiles::users
  include roles_profiles::profiles::sudo
  include roles_profiles::profiles::vnc
  include roles_profiles::profiles::macos_run_puppet
  include roles_profiles::profiles::motd
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::timezone

  # the point of this host
  include roles_profiles::profiles::reprovision_runner
}
