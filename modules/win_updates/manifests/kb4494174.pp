# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_updates::kb4494174 {

    # Description https://support.microsoft.com/en-us/help/4494174/kb4494174-intel-microcode-updates
    windows_updates::kb {'KB4494174':
        ensure => 'present'
    }
}
