# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class mercurial::system_hgrc {

    include mercurial::settings
    include mercurial::cacert
    include shared

    file {
        default: * => $::shared::file_defaults;

        $::mercurial::settings::hgrc_parentdirs:
            ensure => directory;
    }

    # Get systems default root user and group
    $root_user = $::shared::file_defaults['owner']
    $root_group = $::shared::file_defaults['group']

    mercurial::hgrc { $::mercurial::settings::hgrc:
        user  => $root_user,
        group => $root_group,
    }
}
