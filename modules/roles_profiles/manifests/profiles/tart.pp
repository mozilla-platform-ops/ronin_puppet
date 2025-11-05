class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => '2.30.0' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => '10.49.56.161' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  String  $oci_image      = lookup('tart.oci_image', { default_value => 'sequoia-tester:prod-latest' }),
  Integer $worker_count   = lookup('tart.worker_count', { default_value => 2 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {
  # Install Tart
  $tart_url = "https://github.com/cirruslabs/tart/releases/download/${version}/tart.tar.gz"
  $install_dir = '/Applications'
  $bin_path = '/usr/local/bin/tart'

  # Download and install Tart
  exec { 'download_tart':
    command => "curl -L -o /tmp/tart.tar.gz ${tart_url}",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    creates => '/tmp/tart.tar.gz',
    unless  => "test -f ${bin_path} && ${bin_path} --version | grep -q ${version}",
  }

  exec { 'extract_tart':
    command => 'tar -xzf /tmp/tart.tar.gz -C /tmp/',
    path    => ['/usr/bin', '/bin'],
    require => Exec['download_tart'],
    unless  => "test -f ${bin_path} && ${bin_path} --version | grep -q ${version}",
  }

  exec { 'install_tart':
    command => "rm -rf ${install_dir}/Tart.app && mv /tmp/Tart.app ${install_dir}/Tart.app",
    path    => ['/usr/bin', '/bin'],
    require => Exec['extract_tart'],
    unless  => "test -f ${bin_path} && ${bin_path} --version | grep -q ${version}",
  }

  exec { 'remove_quarantine_tart':
    command => "xattr -dr com.apple.quarantine ${install_dir}/Tart.app",
    path    => ['/usr/bin', '/bin'],
    require => Exec['install_tart'],
    onlyif  => "test -d ${install_dir}/Tart.app",
  }

  file { $bin_path:
    ensure  => link,
    target  => "${install_dir}/Tart.app/Contents/MacOS/tart",
    require => Exec['install_tart'],
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
  }

  # Initial VM setup
  exec { 'pull_initial_image':
    command => '/usr/local/bin/tart-pull-image.sh',
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    require => [File['/usr/local/bin/tart-pull-image.sh'], File[$bin_path]],
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
