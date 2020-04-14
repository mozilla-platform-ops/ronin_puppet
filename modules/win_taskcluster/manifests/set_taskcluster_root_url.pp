# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::set_taskcluster_root_url (
    String $taskcluster_root_url
) {

    file { 'TASKCLUSTER_ROOT_URL':
        value => $taskcluster_root_url,
    }
}
