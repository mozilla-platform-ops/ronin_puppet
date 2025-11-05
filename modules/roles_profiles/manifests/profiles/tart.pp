class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => '2.30.0' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => '10.49.56.161' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  String  $oci_image      = lookup('tart.oci_image', { default_value => 'sequoia-tester:prod-latest' }),
  Integer $worker_count   = lookup('tart.worker_count', { default_value => 2 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {
  # Ensure /usr/local/bin exists first
  exec { 'create_usr_local_bin':
    command => 'mkdir -p /usr/local/bin',
    path    => ['/usr/bin', '/bin'],
    unless  => 'test -d /usr/local/bin',
  }

  # Install Tart
  $tart_url = "https://github.com/cirruslabs/tart/releases/download/${version}/tart.tar.gz"
  $install_dir = '/Applications'
  $bin_path = '/usr/local/bin/tart'

  # Download Tart
  exec { 'download_tart':
    command => "curl -L -o /tmp/tart.tar.gz '${tart_url}'",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    unless  => "test -f ${bin_path} && ${bin_path} --version | grep -q '${version}'",
  }

  # Extract Tart (GitHub releases are just gzipped, not tar.gz)
  exec { 'extract_tart':
    command => 'mkdir -p /tmp/tart_extract && tar -xzf /tmp/tart.tar.gz -C /tmp/tart_extract',
    path    => ['/usr/bin', '/bin'],
    require => Exec['download_tart'],
    unless  => "test -f ${bin_path} && ${bin_path} --version | grep -q '${version}'",
  }

  # Install Tart app
  exec { 'install_tart':
    command => 'rm -rf /Applications/Tart.app && mv /tmp/tart_extract/Tart.app /Applications/Tart.app',
    path    => ['/usr/bin', '/bin'],
    require => Exec['extract_tart'],
    unless  => "test -f ${bin_path} && ${bin_path} --version | grep -q '${version}'",
  }

  # Remove quarantine
  exec { 'remove_quarantine_tart':
    command => 'xattr -dr com.apple.quarantine /Applications/Tart.app',
    path    => ['/usr/bin', '/bin'],
    require => Exec['install_tart'],
    onlyif  => 'test -d /Applications/Tart.app',
  }

  # Create symlink
  file { $bin_path:
    ensure  => link,
    target  => '/Applications/Tart.app/Contents/MacOS/tart',
    require => [Exec['install_tart'], Exec['create_usr_local_bin']],
  }

  # Create pull/setup script
  $insecure_flag = $insecure ? {
    true  => '--insecure',
    false => '',
  }

  file { '/usr/local/bin/tart-pull-image.sh':
    ensure  => file,
    mode    => '0755',
    content => epp('roles_profiles/tart/tart-pull-image.sh.epp', {
        registry_host => $registry_host,
        registry_port => $registry_port,
        oci_image     => $oci_image,
        worker_count  => $worker_count,
        insecure_flag => $insecure_flag,
        bin_path      => $bin_path,
    }),
    require => Exec['create_usr_local_bin'],
  }

  # Create manual update script
  file { '/usr/local/bin/tart-update-vms.sh':
    ensure  => file,
    mode    => '0755',
    content => epp('roles_profiles/tart/tart-update-vms.sh.epp', {
        registry_host => $registry_host,
        registry_port => $registry_port,
        oci_image     => $oci_image,
        worker_count  => $worker_count,
        insecure_flag => $insecure_flag,
        bin_path      => $bin_path,
    }),
    require => Exec['create_usr_local_bin'],
  }

  # Initial VM setup
  exec { 'pull_initial_image':
    command => '/usr/local/bin/tart-pull-image.sh',
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    require => [File['/usr/local/bin/tart-pull-image.sh'], File[$bin_path]],
    timeout => 1800, # 30 minutes for large image pulls
    unless  => "${bin_path} list | grep -q sequoia-tester-1",
  }

  # Create LaunchDaemons for each worker
  Integer[1, $worker_count].each |$i| {
    $vm_name = "sequoia-tester-${i}"

    file { "/Library/LaunchDaemons/com.mozilla.tartworker-${i}.plist":
      ensure  => file,
      content => epp('roles_profiles/tart/com.mozilla.tartworker.plist.epp', {
          worker_id => $i,
          vm_name   => $vm_name,
          bin_path  => $bin_path,
      }),
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      require => Exec['pull_initial_image'],
      notify  => Exec["load_tartworker_${i}"],
    }

    exec { "load_tartworker_${i}":
      command     => "launchctl load /Library/LaunchDaemons/com.mozilla.tartworker-${i}.plist",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      unless      => "launchctl list | grep -q com.mozilla.tartworker-${i}",
    }
  }
}
