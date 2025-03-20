# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::mac_v4_signing_dep {
  include roles_profiles::profiles::duo
  include roles_profiles::profiles::gui
  include roles_profiles::profiles::hardware
  include fw::roles::mac_signing
  include roles_profiles::profiles::macos_people_remover
  include roles_profiles::profiles::macos_signer_python
  include roles_profiles::profiles::macos_xcode_tools
  include roles_profiles::profiles::macos_signer_virtualenv_fixer
  include roles_profiles::profiles::mac_v3_signing
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
