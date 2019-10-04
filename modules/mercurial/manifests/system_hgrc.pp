# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class mercurial::system_hgrc {

    include mercurial::settings
    include mercurial::cacert

    file { $::mercurial::settings::hgrc_parentdirs:
        ensure => directory,
        owner  => $mercurial::settings::root_user,
        group  => $mercurial::settings::root_group,
    }

    mercurial::hgrc { $::mercurial::settings::hgrc:
        user  => $mercurial::settings::root_user,
        group => $mercurial::settings::root_group,
    }
}
