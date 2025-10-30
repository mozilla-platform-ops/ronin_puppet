# Installs Docker and Colima using Homebrew and ensures Colima is running.
class roles_profiles::profiles::colima_docker (
  String $package_name = lookup('docker.package_name'),
  String $service_name = lookup('docker.service_name'),
) {
  # Install Docker and Colima via Homebrew
  package { [$package_name, 'colima']:
    ensure   => installed,
    provider => brew,
  }

  # Start Colima if not already running
  exec { 'start_colima':
    command => '/opt/homebrew/bin/colima start --arch aarch64 --vm-type vz --cpu 4 --memory 8 --network-address',
    unless  => '/opt/homebrew/bin/colima status | grep -q "running"',
    path    => ['/opt/homebrew/bin','/usr/local/bin','/usr/bin','/bin'],
    require => Package['colima'],
  }
}
