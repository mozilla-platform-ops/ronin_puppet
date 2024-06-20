# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::gecko_t_linux_netperf {
  include roles_profiles::profiles::linux_base
  include roles_profiles::profiles::cltbld_user

  # TODO: enable some of these?
  #   from modules/roles_profiles/manifests/roles/gecko_t_linux_talos.pp
  # include roles_profiles::profiles::vnc
  # include roles_profiles::profiles::gui
  # include roles_profiles::profiles::google_chrome

  # TODO: add new role_profile with netperf specific stuff
  #   - should be similar to roles_profiles::profiles::gecko_t_linux_talos_generic_worker
  #        (modules/roles_profiles/manifests/profiles/gecko_t_linux_talos_generic_worker.pp)
  # include roles_profiles::profiles::gecko_t_linux_netperf_worker
}
