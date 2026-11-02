class macos_xcode_tools (
  Boolean $enabled = true,
) {
  $clt_dir = '/Library/Developer/CommandLineTools'
  $clt_git = "${clt_dir}/usr/bin/git"

  # softwareupdate has offered Catalina a CLT it can't run (16.4, needs 14.5+),
  # which breaks codesign there. Pin 10.15 to 12.x and replace anything else.
  if $facts['os']['macosx']['version']['major'] == '10.15' {
    $clt_label  = 'Command Line Tools for Xcode-12'
    $clt_ok     = "test -x ${clt_git} && pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | grep -q '^version: 12\\.'"
    $clt_remove = "${clt_ok} || rm -rf ${clt_dir};"
  } else {
    $clt_label  = 'Command Line'
    $clt_ok     = "test -x ${clt_git}"
    $clt_remove = ''
  }

  exec { 'install_xcode_tools':
    command => "${clt_remove} xcode-select -p &> /dev/null; touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress; PROD=\$(softwareupdate -l | grep \"\\*.*${clt_label}\" | tail -n 1 | sed 's/^[^C]* //'); softwareupdate -i \"\$PROD\" --verbose;",
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    unless  => $clt_ok,
    timeout => 1800,
  }
}
