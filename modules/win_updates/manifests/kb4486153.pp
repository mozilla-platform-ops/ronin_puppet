# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_updates::kb4486153 {

    # Description https://support.microsoft.com/en-us/help/4486153/microsoft-net-framework-4-8-on-windows-10-version-1709-windows-10-vers
    windows_updates::kb {'KB4486153':
        ensure => 'present'
    }
}
