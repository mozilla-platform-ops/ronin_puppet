# Installs Docker and Colima using Homebrew and ensures Colima is running.
#
# This version runs Homebrew as the admin user (owner of /opt/homebrew) and
# avoids duplicate file declarations. Requires homebrew_silent_install to run first.
class roles_profiles::profiles::colima_docker (
  String $package_name = lookup('docker.package_name'),
  String $service_name = lookup('docker.service_name'),
) {
  # Ensure Homebrew exists (declared in homebrew_silent_install)
  if !defined(File['/opt/homebrew/bin']) {
    fail('Expected File[/opt/homebrew/bin] to be managed by homebrew_silent_install')
  }

  $brew_path = '/opt/homebrew/bin/brew'

  # Install Docker, Lima, and Colima via Homebrew under the admin user
  exec { 'install_docker_colima':
    command   => "/usr/bin/su - admin -c '${brew_path} install ${package_name} lima colima || true'",
    unless    => "/usr/bin/su - admin -c '${brew_path} list --formula | grep -E \"(${package_name}|lima|colima)\"'",
    path      => ['/opt/homebrew/bin', '/usr/local/bin', '/usr/bin', '/bin'],
    timeout   => 0,
    logoutput => true,
    require   => File['/opt/homebrew/bin'],
  }

  # Verify all binaries exist - run colima version as admin user to have proper $HOME
  exec { 'verify_docker_colima':
    command => "/opt/homebrew/bin/docker --version && /usr/bin/su - admin -c '/opt/homebrew/bin/colima version'",
    unless  => "/opt/homebrew/bin/docker --version >/dev/null 2>&1 && /usr/bin/su - admin -c '/opt/homebrew/bin/colima version >/dev/null 2>&1'",
    path    => ['/opt/homebrew/bin','/usr/local/bin','/usr/bin','/bin'],
    require => Exec['install_docker_colima'],
  }

  # Start Colima as admin user with proper PATH
  exec { 'start_colima':
    command   => '/usr/bin/su - admin -c "PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/colima start --arch aarch64 --vm-type vz --cpu 4 --memory 8 --network-address"',
    unless    => '/usr/bin/su - admin -c "PATH=/opt/homebrew/bin:\$PATH /opt/homebrew/bin/colima status" | grep -q "running"',
    path      => ['/opt/homebrew/bin','/usr/local/bin','/usr/bin','/bin'],
    require   => Exec['verify_docker_colima'],
    logoutput => true,
    timeout   => 300,
  }
}
