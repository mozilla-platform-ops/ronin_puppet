# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_ultravnc::configuration {

    require win_ultravnc::install

    file { $win_ultravnc::ini_file:
        content => epp('win_ultravnc/ultravnc.ini.epp'),
    }
}
