# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_netperf_worker {
  class { 'roles_profiles::profiles::gecko_t_linux_generic_worker':
    worker_type                    => 'gecko-t-linux-netperf-1804',
    lookup_key                     => 'gecko_t_linux_netperf',
    include_py2                    => true,
    include_cltbld_and_apt_cleaner => true,
    include_netperf                => true,
    generic_worker_version         => 'v65.1.0',
    generic_worker_sha256          => 'ebd6773d0d61705e975c168bf58f9f0070c5abec46f34fc61590eaf5d3b1931f',
    taskcluster_proxy_version      => 'v65.1.0',
    taskcluster_proxy_sha256       => '1c498f6f9390fa2bc069be747a24b4b17436cfd28df35e9adb38c48fab813985',
    livelog_version                => 'v65.1.0',
    livelog_sha256                 => '543b66a900e49212b31fbe4fa4dd1a4e476597ae4f6ddb0ce48bba3437646dab',
    start_worker_version           => 'v65.1.0',
    start_worker_sha256            => '03f69ee42b51b493415fb25396922691992581af0d26df31bc87144f81a75285',
  }
}
