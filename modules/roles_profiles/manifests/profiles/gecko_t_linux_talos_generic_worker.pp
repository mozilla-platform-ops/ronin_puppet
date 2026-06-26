# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_talos_generic_worker {
  class { 'roles_profiles::profiles::gecko_t_linux_generic_worker':
    worker_type                    => 'gecko-t-linux-talos-1804',
    lookup_key                     => 'gecko_t_linux_talos',
    include_py2                    => true,
    include_pulseaudio             => true,
    include_cltbld_and_apt_cleaner => true,
    generic_worker_version         => 'v61.0.0',
    generic_worker_sha256          => '9aed38c86c1c0417725a677318857266e51bd28e69b2e27586edd72e658af3f0',
    taskcluster_proxy_version      => 'v61.0.0',
    taskcluster_proxy_sha256       => '639b3333cfefaf4d2e449c2962c20912e4449c3ffb9ab6d899c237d87e46712c',
    livelog_version                => 'v61.0.0',
    livelog_sha256                 => '0513c85b3ad2f289961992ec166ee1e890ad033a1b485c29c69653049c369e23',
    start_worker_version           => 'v61.0.0',
    start_worker_sha256            => 'ddf74465e77e2a97a12c87a15dcd9599952127cb38b2e7040bc3177802b1151e',
  }
}
