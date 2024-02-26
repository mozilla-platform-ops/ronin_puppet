# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::clean_appstate_13_plus (
  String $user,
  String $group,
) {
  file {
    "/Users/${user}/Library/Saved Application State":
      ensure  => directory,
      owner   => $user,
      group   => $group,
      mode    => '0500', # remove write permission
      require => Exec['create_macos_user'];
  }
  file {
    "/Users/${user}/Library/Preferences/.GlobalPreferences.plist":
      ensure  => file,
      owner   => $user,
      group   => $group,
      mode    => '0600',
      require => Exec['create_macos_user'];
  }

  tidy {
    "/Users/${user}/Library/Saved Application State":
      matches => '*.savedState',
      rmdirs  => true,
      recurse => true,
      require => Exec['create_macos_user'];
  }

  file { "/Users/${user}/Library/Preferences/ByHost/":
    ensure  => 'directory',
    owner   => $user,
    group   => $group,
    mode    => '0700',
    content => '',
    #require => File["/Users/${account_username}/Library/Preferences/ByHost"];
  }

  file { "/Users/${user}/Library/Preferences/ByHost/com.apple.loginwindow.${::facts[system_profiler][hardware_uuid]}.plist":
    ensure  => 'file',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0000',
    content => '',
    #require => File["/Users/${account_username}/Library/Preferences/ByHost"];
  }
  # Sneaking this in here
  file { "/Users/${user}/Library/LaunchAgents":
    ensure => directory,
    owner  => $user,
    group  => $group,
    mode   => '0755',
  }
}
