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

    # The agent watches this file (WatchPaths), so it must exist for the watch
    # to be armed before the first task runs. replace => false so we create it
    # when absent but never clobber the path the harness writes into it.
    file { $trigger_file:
      ensure  => present,
      owner   => 'cltbld',
      group   => 'staff',
      mode    => '0644',
      replace => false,
    }

    # bootout then bootstrap so a changed plist (e.g. StartInterval -> WatchPaths)
    # is actually re-read. launchctl kickstart only restarts the already-loaded
    # job definition and would not pick up plist edits.
    exec { 'load or restart screenshot agent':
      command     => "/bin/bash -c '/bin/launchctl bootout gui/${cltbld_uid}/com.mozilla.screencapture 2>/dev/null; \
                    /bin/launchctl bootstrap gui/${cltbld_uid} \"${launchagent_path}\" 2>/dev/null; exit 0'",
      path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
      refreshonly => true,
      subscribe   => File[$launchagent_path],
    }
  }
}
