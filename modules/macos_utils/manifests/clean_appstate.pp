# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::clean_appstate (
  String $user,
  String $group,
) {
  file {
    "/Users/${user}/Library/Saved Application State":
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0500', # remove write permission
      require => File["/Users/${user}/Library"];
    "/Users/${user}/Library/Preferences/.GlobalPreferences.plist":
      ensure  => file,
      owner   => $user,
      group   => $group,
      mode    => '0600',
      require => File["/Users/${user}/Library/Preferences"];
  }

  # clean out saved application state on OS X, and prevent new state from being written
  # two different ways
  tidy {
    "/Users/${user}/Library/Saved Application State":
      matches => '*.savedState',
      rmdirs  => true,
      recurse => true,
      require => File["/Users/${user}/Library/Saved Application State"];
  }

  # In order to prevent apps from reopening on reboot, we change the owner to root and remove write access
  file { "/Users/${user}/Library/Preferences/ByHost/com.apple.loginwindow.${::facts[system_profiler][hardware_uuid]}.plist":
    ensure  => 'file',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0000',
    content => '',
    require => File["/Users/${user}/Library/Preferences/ByHost"];
  }

  # set the user preference to not save app states
  macos_utils::defaults { "${user}-NSQuitAlwaysKeepsWindows":
    domain   => "/Users/${user}/Library/Preferences/.GlobalPreferences.plist",
    key      => 'NSQuitAlwaysKeepsWindows',
    value    => '0',
    val_type => 'int',
    user     => $user,
    require  => File["/Users/${user}/Library/Preferences/.GlobalPreferences.plist"];
  }

  # Set user preference to always show scrollbar
  macos_utils::defaults { "${user}-AppleShowScrollBars":
    domain   => "/Users/${user}/Library/Preferences/.GlobalPreferences.plist",
    key      => 'AppleShowScrollBars',
    value    => 'Always',
    val_type => 'string',
    user     => $user,
    require  => File["/Users/${user}/Library/Preferences/.GlobalPreferences.plist"];
  }
}
