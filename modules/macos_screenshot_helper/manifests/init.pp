class macos_screenshot_helper (
  Boolean $enabled = true,
  String $screenshot_dir    = '/Users/cltbld/Desktop',
  String $trigger_file      = '/Users/cltbld/.trigger_screenshot',
  String $script_path       = '/Users/cltbld/bin/capture-on-demand.sh',
  String $launchagent_path  = '/Users/cltbld/Library/LaunchAgents/com.mozilla.screencapture.plist',
) {
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

  exec { 'bootstrap screenshot helper':
    command => "/usr/bin/launchctl bootstrap gui/501 '${launchagent_path}'",
    user    => 'cltbld',
    unless  => "/usr/bin/launchctl print gui/501/com.mozilla.screencapture | /usr/bin/grep -q 'PID'",
    require => File[$launchagent_path],
    path    => ['/usr/bin', '/bin', '/usr/sbin', '/sbin'],
  }
}
