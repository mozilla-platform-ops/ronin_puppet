# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class mercurial::ext::robustcheckout {

    include mercurial::ext::common

    file { "${mercurial::settings::hgext_dir}/robustcheckout.py":
        source => 'puppet:///modules/mercurial/robustcheckout.py',
    }
}
