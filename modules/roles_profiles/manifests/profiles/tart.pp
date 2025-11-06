class roles_profiles::profiles::tart (
  String  $version        = '2.30.0',
  String  $registry_host  = '10.49.56.161',
  Integer $registry_port  = 5000,
  String  $oci_image      = 'sequoia-tester:prod-latest',
  Integer $worker_count   = 2,
  Boolean $insecure       = true,
  String  $user           = 'admin',
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
  $tart_url = "https://github.com/cirruslabs/tart/releases/download/${version}/tart.tar.gz"

  exec { 'install_tart':
    command => "/bin/bash -c 'set -e && TMP_DIR=\$(mktemp -d) && cd \$TMP_DIR && curl -L -o tart.tar.gz ${tart_url} && tar -xzf tart.tar.gz && rm -rf ${install_dir}/Tart.app && mv Tart.app ${install_dir}/Tart.app && xattr -dr com.apple.quarantine ${install_dir}/Tart.app || true && mkdir -p /usr/local/bin && ln -sf ${install_dir}/Tart.app/Contents/MacOS/tart ${bin_path} && cd / && rm -rf \$TMP_DIR'",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    unless  => "test -f ${bin_path}",
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
        user          => $user,
    }),
    require => Exec['install_tart'],
  }

  # Ensure LaunchAgents directory exists for user
  file { "/Users/${user}/Library/LaunchAgents":
    ensure => directory,
    owner  => $user,
    group  => 'staff',
    mode   => '0755',
  }

  # Initial VM setup - run as user, not root
  exec { 'pull_initial_image':
    command => "su - ${user} -c '/usr/local/bin/tart-pull-image.sh'",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    require => [File['/usr/local/bin/tart-pull-image.sh']],
    timeout => 1800,
    unless  => "su - ${user} -c '${bin_path} list' | grep -q sequoia-tester-1",
  }

  # Create LaunchAgents for each worker (runs as user, not root)
  Integer[1, $worker_count].each |$i| {
    $vm_name = "sequoia-tester-${i}"

    file { "/Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist":
      ensure  => file,
      content => epp('roles_profiles/tart/com.mozilla.tartworker.plist.epp', {
          worker_id => $i,
          vm_name   => $vm_name,
          bin_path  => $bin_path,
      }),
      owner   => $user,
      group   => 'staff',
      mode    => '0644',
      require => [Exec['pull_initial_image'], File["/Users/${user}/Library/LaunchAgents"]],
      notify  => Exec["load_tartworker_${i}"],
    }

    exec { "load_tartworker_${i}":
      command     => "su - ${user} -c 'launchctl load /Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist'",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      unless      => "su - ${user} -c 'launchctl list' | grep -q com.mozilla.tartworker-${i}",
    }
  }
}
