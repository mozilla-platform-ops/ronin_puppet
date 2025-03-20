class macos_signer_virtualenv_fixer (
  Boolean $enabled = true,
) {
  if $enabled {
    exec { 'fix_virtualenv':
      command     => '/usr/local/bin/python3 -m pip install --upgrade pip &&
      /usr/local/bin/python3 -m pip install --upgrade --break-system-packages --force-reinstall virtualenv',
      path        => ['/bin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/Library/Frameworks/Python.framework/Versions/3.11/bin'],
      user        => 'root',
      logoutput   => true,  # Logs the output to Puppet
      refreshonly => false, # Ensures it runs every time for testing
      unless      => '/usr/local/bin/python3 -m pip show virtualenv >/dev/null 2>&1 &&
      ! /usr/local/bin/python3 -m pip list --outdated | grep -q "^virtualenv "', # Only if virtualenv is outdated
    }
  }
}
