# Sets up and runs a local Docker-based OCI registry for Tart VM images.
class roles_profiles::profiles::oci_registry (
  Integer $registry_port    = lookup('docker.registry_port', { default_value => 5000 }),
  String  $registry_network = lookup('docker.registry_network', { default_value => 'bridge' }),
  Boolean $enable_delete    = lookup('oci_registry.enable_delete', { default_value => true }),
  String  $registry_dir     = lookup('oci_registry.registry_dir', { default_value => '/opt/registry/data' }),
  String  $registry_name    = lookup('oci_registry.registry_name', { default_value => 'tart-registry' }),
) {
  # Ensure data directory exists
  file { $registry_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Remove any existing container to prevent conflicts
  exec { 'remove_old_registry_container':
    command   => "/usr/bin/su - admin -c 'PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/docker rm -f ${registry_name} || true'",
    onlyif    => "/usr/bin/su - admin -c 'PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/docker ps -a --filter name=${registry_name} --format {{.Names}}' | grep -q ${registry_name}",
    path      => ['/opt/homebrew/bin', '/usr/bin', '/bin'],
    logoutput => on_failure,
    require   => Class['roles_profiles::profiles::colima_docker'],
  }

  # Build the docker run command with correct argument ordering
  $docker_run_cmd = sprintf(
    "/usr/bin/su - admin -c 'PATH=/opt/homebrew/bin:%%s /opt/homebrew/bin/docker run -d --network %s -p %s:%s --restart=always --name %s -v %s:/var/lib/registry -e REGISTRY_HTTP_ADDR=0.0.0.0:%s -e REGISTRY_STORAGE_DELETE_ENABLED=%s registry:2'",
    '$PATH',
    $registry_network,
    $registry_port,
    $registry_port,
    $registry_name,
    $registry_dir,
    $registry_port,
    $enable_delete
  )

  # Run the registry container
  exec { 'run_registry_container':
    command   => $docker_run_cmd,
    unless    => "/usr/bin/su - admin -c 'PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/docker ps --filter name=${registry_name} --format {{.Names}}' | grep -q ${registry_name}",
    path      => ['/opt/homebrew/bin','/usr/bin','/bin'],
    logoutput => on_failure,
    require   => Exec['remove_old_registry_container'],
  }

  # Ensure the container is running
  exec { 'ensure_registry_running':
    command   => "/usr/bin/su - admin -c 'PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/docker start ${registry_name}'",
    unless    => "/usr/bin/su - admin -c 'PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/docker ps --filter name=${registry_name} --format {{.Names}}' | grep -q ${registry_name}",
    path      => ['/opt/homebrew/bin','/usr/bin','/bin'],
    logoutput => on_failure,
    require   => Exec['run_registry_container'],
  }

  # Verify the registry responds
  exec { 'verify_registry':
    command   => "/usr/bin/curl -fsSL http://localhost:${registry_port}/v2/ || (echo 'Registry not reachable' && exit 1)",
    path      => ['/usr/bin','/bin'],
    tries     => 3,
    try_sleep => 5,
    logoutput => on_failure,
    require   => Exec['ensure_registry_running'],
  }
}
