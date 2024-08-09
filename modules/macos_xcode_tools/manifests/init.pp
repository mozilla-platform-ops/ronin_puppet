class macos_xcode_tools (
  Boolean $enabled = true,
) {
  $xcode_select_path = '/Library/Developer/CommandLineTools'

  exec { 'install_xcode_tools':
    command => "xcode-select -p &> /dev/null; touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress; PROD=\$(softwareupdate -l | grep \"\\*.*Command Line\" | tail -n 1 | sed 's/^[^C]* //'); softwareupdate -i \"\$PROD\" --verbose;",
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    unless  => "test -d ${xcode_select_path}",
  }
}
