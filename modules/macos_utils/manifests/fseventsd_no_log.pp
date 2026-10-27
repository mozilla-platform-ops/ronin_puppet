# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Stop fseventsd keeping a persistent event history on the Data volume.
# Builders reboot after every task and each task chowns and checks out
# whole trees, so the history grows without bound (34G / 870k files on
# macmini-m4-122) and fseventsd pegs a core from boot, slowing every
# filesystem operation in the task. Live FSEvents are unaffected.
class macos_utils::fseventsd_no_log {

    $fseventsd_dir = '/System/Volumes/Data/.fseventsd'

    # Drop the existing history once, then leave a no_log marker so
    # fseventsd stops writing it from the next boot on.
    exec { 'fseventsd_no_log':
        command => "/bin/rm -rf ${fseventsd_dir} && /bin/mkdir -m 0700 ${fseventsd_dir} && /usr/bin/touch ${fseventsd_dir}/no_log",
        creates => "${fseventsd_dir}/no_log",
        onlyif  => '/bin/test -d /System/Volumes/Data',
    }
}
