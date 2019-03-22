# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class users::global {

    shellprofile::file {
        'ps1':
            ensure  => 'present',
            content => template("${module_name}/ps1.sh.erb");
        'timeout':
            ensure  => 'present',
            content => 'export TMOUT=86400';  # Shells timeout after 1 day
    }
}
