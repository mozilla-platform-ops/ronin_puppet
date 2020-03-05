# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::livelog (
    String $generic_worker_dir,
    String $livelog_exe_source
) {

    require win_taskcluster::generic_worker

    file { "${generic_worker_dir}\\livelog.exe":
        source  => $livelog_exe_source,
    }
}
