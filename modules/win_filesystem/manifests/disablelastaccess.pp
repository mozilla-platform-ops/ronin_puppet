# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::disablelastaccess {

    shared::execonce { 'disablelastaccess':
        command => "${facts[custom_win_system32]}\\fsutil.exe behavior set disablelastaccess 1",
    }
}
