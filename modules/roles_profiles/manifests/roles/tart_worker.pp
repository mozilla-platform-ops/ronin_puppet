# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Physical macOS host that runs gecko-t-osx-1500-m-vms tester VMs via Tart.
# Manages worker VM lifecycle via per-VM system LaunchDaemons (launchd_type:
# daemon in hiera), which load headlessly and survive reboot without a console
# session. The Taskcluster worker identity lives inside the VM image, so this
# host role only manages the Tart layer.
#
# manage_image is false for this role (see data/roles/tart_worker.yaml): on
# macOS 15 `tart pull` only succeeds from the console GUI session, so the image
# is seeded once by hand and puppet only manages tart + the launchd unit. The
# VMs run under the admin user, so admin auto-login is still set out-of-band
# (not by puppet) for the manual image-seed step: macOS needs both the
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
