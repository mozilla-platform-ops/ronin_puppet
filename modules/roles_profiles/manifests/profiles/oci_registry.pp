# Sets up and runs a local Docker-based OCI registry for Tart VM images.
class roles_profiles::profiles::oci_registry (
  Integer $registry_port    = lookup('docker.registry_port', { default_value => 5000 }),
  String  $registry_network = lookup('docker.registry_network', { default_value => 'host' }),
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

  # Use a heredoc for the docker run command
  $docker_run_cmd = @("CMD"/L)
    docker run -d --network ${registry_network} \
      -p ${registry_port}:${registry_port} \
      --restart=always --name ${registry_name} \
      -v ${registry_dir}:/var/lib/registry \
      -e REGISTRY_HTTP_ADDR=0.0.0.0:${registry_port} \
      -e REGISTRY_STORAGE_DELETE_ENABLED=${enable_delete} registry:2
    | CMD

  exec { 'run_registry_container':
    command => $docker_run_cmd,
    unless  => "docker ps --filter 'name=${registry_name}' --format '{{.Names}}' | grep -q ${registry_name}",
    path    => ['/opt/homebrew/bin', '/usr/bin', '/bin'],
    require => Class['roles_profiles::profiles::colima_docker'],
  }

  service { 'docker-registry':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    start      => "docker start ${registry_name}",
    stop       => "docker stop ${registry_name}",
    status     => "docker ps --filter 'name=${registry_name}' --format '{{.Names}}' | grep -q ${registry_name}",
  }
}
