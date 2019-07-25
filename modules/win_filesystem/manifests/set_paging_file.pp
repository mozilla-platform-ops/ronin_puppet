# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_filesystem::set_paging_file (
    String $location,
    Integer $min_size,
    Integer $max_size
) {

    $paging_file_key = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session\ Manager\\Memory\ Management"

    registry_value { "${paging_file_key}\\PagingFiles":
        type  => arrays,
        value => "${location} ${min_size} ${max_size}",
    }

}
