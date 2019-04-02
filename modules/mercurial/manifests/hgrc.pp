# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define mercurial::hgrc (
    String $user,
    String $group,
    String $path = $title,
) {

    include mercurial::settings

    file { $path:
        mode    => '0644',
        owner   => $user,
        group   => $group,
        content => template('mercurial/hgrc.erb'),
    }
}
