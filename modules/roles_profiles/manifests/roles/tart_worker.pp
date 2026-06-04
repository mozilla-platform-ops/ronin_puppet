# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Physical macOS host that runs gecko-t-osx-1500-m-vms tester VMs via Tart.
# Pulls sequoia-tester from the local OCI registry and manages worker VM
# lifecycle via per-VM LaunchAgents. The Taskcluster worker identity lives
# inside the VM image, so this host role only manages the Tart layer.
#
# Admin GUI auto-login (required for the gui-domain tartworker LaunchAgents to
# run) is set out-of-band, not by puppet: macOS needs both the
# com.apple.loginwindow autoLoginUser preference and /etc/kcpassword, and the
# latter (the obfuscated admin password) cannot be delivered by a config
# profile. Kept out of this role to avoid the admin password entering vault.
class roles_profiles::roles::tart_worker {
  # The macOS application firewall blocks Tart's image-pull connections to the
  # OCI registry (surfaces as "The Internet connection appears to be offline"),
  # so it must be disabled — matching the existing tester hosts.
  include roles_profiles::profiles::macos_disable_firewall
  include roles_profiles::profiles::tart
}
