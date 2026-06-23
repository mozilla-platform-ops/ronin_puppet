# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Physical macOS host that runs gecko-3b builder VMs via Tart.
# Pulls sequoia-gecko3b-vms from the local OCI registry and manages
# worker VM lifecycle via per-VM LaunchAgents.
class roles_profiles::roles::gecko_3_b_osx_arm64_vms_host {
  include macos_utils::disable_bluetooth_setup
  include roles_profiles::profiles::macos_disable_firewall
  include roles_profiles::profiles::macos_run_puppet
  include roles_profiles::profiles::motd
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::relops_users
  include roles_profiles::profiles::sudo
  include roles_profiles::profiles::timezone
  include roles_profiles::profiles::users
  include roles_profiles::profiles::vnc
  include roles_profiles::profiles::tart
}
