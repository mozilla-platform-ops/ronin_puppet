# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Tart VM variant of roles_profiles::roles::mac_v4_signing_dep.
#
# Identical to the bare-metal dep signer role except for the two profiles noted
# below, which cannot work inside a virtual machine. Keep this role in sync with
# mac_v4_signing_dep.pp when that one changes.
#
# NOTE: the signer *flavor* (dep / ff-prod / tb-prod / ...) is NOT chosen by this
# role. roles_profiles::profiles::mac_signing derives it from the hostname, and
# its `default` case is 'ff-prod'. A VM running this role MUST be named to match
# /^dep-mac-v(3|4)-signing\d+/ or it will silently configure itself as a
# production Firefox signer. See mac/signer14/set_hostname.sh in macos-vms,
# which fails closed rather than allow that.
class roles_profiles::roles::mac_v4_signing_dep_vms {
  # Excluded: roles_profiles::profiles::hardware
  #   It calls macos_utils::assert_firmware, which fail()s unless
  #   $facts['system_profiler']['model_identifier'] is a key in the
  #   apple_firmware_acceptance hash. A Tart guest reports 'VirtualMac2,1' and
  #   has no Apple boot ROM to assert against, so the check is both guaranteed
  #   to fail and meaningless here. Same reasoning as gecko_t_osx_1500_m_vms.
  #
  # Excluded: roles_profiles::profiles::duo
  #   duo::duo_unix installs `auth required pam_duo.so` into /etc/pam.d/sshd
  #   (confirmed present on fx-mac-v4-signing01). The Packer build authenticates
  #   over SSH as `admin` with a password, so enabling Duo mid-build locks the
  #   remaining provisioners out of the guest. A VM is reached through its Tart
  #   host rather than directly, so the second factor belongs on the host.
  include roles_profiles::profiles::gui
  include fw::roles::mac_signing
  include roles_profiles::profiles::macos_people_remover
  include roles_profiles::profiles::macos_xcode_tools
  include roles_profiles::profiles::mac_signing
  include roles_profiles::profiles::motd
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::packages_installed
  include roles_profiles::profiles::relops_users
  include roles_profiles::profiles::remove_bootstrap_user
  include roles_profiles::profiles::signing_users
  include roles_profiles::profiles::sudo
  include roles_profiles::profiles::timezone
  include roles_profiles::profiles::users
  include roles_profiles::profiles::vault_agent
  include roles_profiles::profiles::vnc
}
