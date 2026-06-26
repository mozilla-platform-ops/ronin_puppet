# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_2204_talos_generic_worker {
  class { 'roles_profiles::profiles::gecko_t_linux_generic_worker':
    worker_type               => 'gecko-t-linux-talos-2204',
    generic_worker_version    => 'v44.23.2',
    generic_worker_sha256     => '4b65b06281848749500063a53190d0222372fe7252ef77f935081bfbfa915ebe',
    taskcluster_proxy_version => 'v44.23.2',
    taskcluster_proxy_sha256  => 'af0559355a607ecc933e0109b12c187c2d7679a4b9b0044ad1c43b122000e3c5',
    livelog_version           => 'v44.23.2',
    livelog_sha256            => '0adbad0397aa608f4b826bff0dc504d2f9f4efba6474ec4c0d8f8ee22cf2ee90',
    start_worker_version      => 'v44.23.2',
    start_worker_sha256       => '05b00bbca08477d79613025ee877b8f0a925ab3c6063ef62316c9017ccce5881',
  }
}
