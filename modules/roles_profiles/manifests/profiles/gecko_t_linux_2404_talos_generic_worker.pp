# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_2404_talos_generic_worker {
  class { 'roles_profiles::profiles::gecko_t_linux_generic_worker':
    worker_type               => 'gecko-t-linux-talos-2404',
    include_pulseaudio        => true,
    include_openbox           => true,
    taskcluster_binary_source => 'github',
    taskcluster_version       => 'v88.0.2',
    generic_worker_sha256     => {
      'amd64' => '0fcbdb1f7462e0b36f0d89a6bf92ec1e70a1356d6149e01c462f53380771e662',
      'arm64' => '664c2aeb0f713ffe68534c6540fda26f073a0e00839b9b2fb657861ca4863d52',
    },
    taskcluster_proxy_sha256  => {
      'amd64' => 'e238eaec6cd283de3a77a4fe8fff504bff819ac28cba92adec3502fe99066850',
      'arm64' => '65869c93477346037434e6268ded4cd37c35dcf16f454df33b2ac89d7202f026',
    },
    livelog_sha256            => {
      'amd64' => 'ee06ad486098942d3180182cd91f3b40822f045f6bd1f606c868ae0ddcdc5389',
      'arm64' => '86ba3a821f93dbcbf2673abc06882e9611a5a005ec01c27892cc1ed614880792',
    },
    start_worker_sha256       => {
      'amd64' => '12c44a7e6f4fc4cd561ca172f3c4521962b45340bd4500384348087a19dc9483',
      'arm64' => 'be4361d352bd60fd4b728dc5fb97a7c7550a42358437502056fbe31d5cc9e51e',
    },
  }

  require linux_host_lifecycle
  Class['roles_profiles::profiles::cltbld_user'] -> Class['linux_host_lifecycle']
}
