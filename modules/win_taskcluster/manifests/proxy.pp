# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::proxy (
    String $generic_worker_dir,
    String $desired_proxy_version,
    String $current_proxy_version,
    String $proxy_exe_source
) {

    require win_taskcluster::generic_worker

    $proxy_exe_path = "${generic_worker_dir}\\taskcluster-proxy.exe"

    file { $proxy_exe_path:
        source => $proxy_exe_source,
    }
}
