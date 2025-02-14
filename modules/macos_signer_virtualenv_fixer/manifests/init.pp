class macos_signer_virtualenv_fixer (
  Boolean $enabled = true,
) {
  if $enabled {
    exec { 'fix_virtualenv':
      command     => "/usr/bin/python3 -m pip install --upgrade --force-reinstall virtualenv &&
                  /usr/bin/python3 -m virtualenv /usr/local/builds/scriptworker/virtualenv &&
                  /usr/sbin/chown -R cltbld:staff /usr/local/builds/scriptworker/virtualenv",
      path        => ['/bin', '/usr/bin', '/usr/sbin', '/usr/local/bin'],
      user        => 'root',
      logoutput   => true,  # Logs the output to Puppet
      refreshonly => false, # Ensures it runs every time for testing
      notify      => Notify['Executed fix_virtualenv'],
    }

    notify { 'Executed fix_virtualenv':
      message => 'The fix_virtualenv exec block has run successfully.',
    }
  }
}
