class macos_screenshot_helper (
  Boolean $enabled = true,
  String $screenshot_dir    = '/Users/cltbld/Desktop',
  String $trigger_file      = '/Users/cltbld/.trigger_screenshot',
  String $script_path       = '/Users/cltbld/bin/capture-on-demand.sh',
  String $launchagent_path  = '/Users/cltbld/Library/LaunchAgents/com.mozilla.screencapture.plist',
) {
  if $enabled {
    $darwin_major = Integer($facts['os']['release']['major'])

    if $darwin_major <= 20 {
      $cltbld_uid = '36'
    } else {
      $cltbld_uid = '555'
    }
    file { '/Users/cltbld/bin':
      ensure => directory,
      owner  => 'cltbld',
      group  => 'staff',
      mode   => '0755',
    }

    file { $script_path:
      ensure => file,
      owner  => 'cltbld',
      group  => 'staff',
      mode   => '0755',
      source => 'puppet:///modules/macos_screenshot_helper/capture-on-demand.sh',
    }

    file { $launchagent_path:
      ensure => file,
      owner  => 'cltbld',
      group  => 'staff',
      mode   => '0644',
      source => 'puppet:///modules/macos_screenshot_helper/com.mozilla.screencapture.plist',
    }

    exec { 'load or restart screenshot agent':
      command => "/bin/bash -c 'if /bin/launchctl print gui/${cltbld_uid}/com.mozilla.screencapture 2>/dev/null; then \
                    /bin/launchctl kickstart -k gui/${cltbld_uid}/com.mozilla.screencapture; \
                  else \
                    /bin/launchctl bootstrap gui/${cltbld_uid} \"${launchagent_path}\"; \
                  fi'",
      unless  => "/bin/launchctl print gui/${cltbld_uid}/com.mozilla.screencapture 2>/dev/null | /usr/bin/grep -q 'PID'",
      path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
      require => File[$launchagent_path],
    }
  }
}
