# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster_cloud::proxy (
  String $proxy_exe_path,
  String $proxy_exe_source
) {
  require win_taskcluster_cloud::generic_worker

  file { $proxy_exe_path:
    source  => $proxy_exe_source,
  }
}
