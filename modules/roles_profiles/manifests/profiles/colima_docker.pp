class roles_profiles::profiles::colima_docker (
  String $package_name = lookup('docker.package_name'),
  String $service_name = lookup('docker.service_name'),
) {

  package { [$package_name, 'colima']:
    ensure => installed,
  }

  exec { 'start_colima':
    command => '/opt/homebrew/bin/colima start --arch aarch64 --vm-type vz --cpu 4 --memory 8 --network-address',
    unless  => 'pgrep -x colima',
    path    => ['/opt/homebrew/bin','/usr/bin','/bin'],
  }
}
