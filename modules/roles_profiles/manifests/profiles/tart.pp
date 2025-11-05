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

  # Install Tart - use a single exec like your working script
  $install_dir = '/Applications'
  $bin_path = '/usr/local/bin/tart'

  exec { 'install_tart':
    command => "/bin/bash -c '\
      set -e; \
      TMP_DIR=\$(mktemp -d); \
      cd \$TMP_DIR; \
      curl -L -o tart.tar.gz https://github.com/cirruslabs/tart/releases/download/${version}/tart.tar.gz; \
      tar -xzf tart.tar.gz; \
      rm -rf ${install_dir}/Tart.app; \
      mv Tart.app ${install_dir}/Tart.app; \
      xattr -dr com.apple.quarantine ${install_dir}/Tart.app || true; \
      mkdir -p /usr/local/bin; \
      ln -sf ${install_dir}/Tart.app/Contents/MacOS/tart ${bin_path}; \
      cd /; \
      rm -rf \$TMP_DIR'",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    unless  => "test -f ${bin_path} && ${bin_path} --version 2>/dev/null | grep -q '${version}'",
    timeout => 600,
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
    require => Exec['install_tart'],
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
    require => Exec['install_tart'],
  }

  # Initial VM setup
  exec { 'pull_initial_image':
    command => '/usr/local/bin/tart-pull-image.sh',
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    require => [File['/usr/local/bin/tart-pull-image.sh']],
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
