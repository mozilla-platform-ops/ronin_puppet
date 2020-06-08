# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::uninstall_homebrew {

    exec { 'run_homebrew_uninstaller':
        path      => '/usr/local/bin:/usr/bin:/usr/sbin:/bin',
        command   => '/bin/bash -c "set - -f $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"',
        onlyif    => '/bin/test -e /usr/local/bin/brew',
        logoutput => true,
    }
}
