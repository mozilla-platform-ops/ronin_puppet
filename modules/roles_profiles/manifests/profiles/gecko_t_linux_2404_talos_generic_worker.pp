# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_2404_talos_generic_worker {
  class { 'roles_profiles::profiles::gecko_t_linux_generic_worker':
    worker_type                    => 'gecko-t-linux-talos-2404',
    include_pulseaudio             => true,
    include_openbox                => true,
    include_cltbld_and_apt_cleaner => true,
    generic_worker_version         => 'v88.0.2',
    generic_worker_sha256          => '0fcbdb1f7462e0b36f0d89a6bf92ec1e70a1356d6149e01c462f53380771e662',
    taskcluster_proxy_version      => 'v88.0.2',
    taskcluster_proxy_sha256       => 'e238eaec6cd283de3a77a4fe8fff504bff819ac28cba92adec3502fe99066850',
    livelog_version                => 'v88.0.2',
    livelog_sha256                 => 'ee06ad486098942d3180182cd91f3b40822f045f6bd1f606c868ae0ddcdc5389',
    start_worker_version           => 'v88.0.2',
    start_worker_sha256            => '12c44a7e6f4fc4cd561ca172f3c4521962b45340bd4500384348087a19dc9483',
  }
}
