# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::clean_appstate (
    String $user,
    String $group,
) {

    # clean out saved application state on OS X, and prevent new state from being written
    # two different ways
    tidy {
        "/Users/${user}/Library/Saved Application State":
            matches => '*.savedState',
            rmdirs  => true,
            recurse => true;
    }

    file {
        "/Users/${user}/Library":
            ensure  => directory,
            owner   => $user,
            group   => $group,
            mode    => '0755',
            require => File["/Users/${user}"];
        "/Users/${user}/Library/Preferences":
            ensure  => directory,
            owner   => $user,
            group   => $group,
            mode    => '0700',
            require => File["/Users/${user}/Library"];
        "/Users/${user}/Library/Saved Application State":
            ensure  => directory,
            owner   => $user,
            group   => $group,
            mode    => '0500', # remove write permission
            require => File["/Users/${user}/Library"];
    }

    # set the user preference to not save app states
    macos_utils::defaults { "${user}-NSQuitAlwaysKeepsWindows":
            domain  => "/Users/${user}/Library/Preferences/.GlobalPreferences.plist",
            key     => 'NSQuitAlwaysKeepsWindows',
            value   => '0',
            type    => 'int',
            require => File["/Users/${user}/Library/Preferences"];
    }
}
