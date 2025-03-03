class macos_signer_python (
  Boolean $enabled = true,
) {
  $pkg_url    = 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/common/python-3.11-macosx10.9.pkg'
  $pkg_name   = 'python-3.11-macosx10.9.pkg'
  $download_path = "/tmp/${pkg_name}"

  # Ensure the required package is downloaded
  exec { 'download_python_pkg':
    command => "/usr/bin/curl -o ${download_path} ${pkg_url}",
    unless  => "/usr/bin/python3 --version 2>&1 | /usr/bin/grep -q '3.11'",
    creates => $download_path,
    path    => ['/usr/bin', '/usr/sbin'],
  }

  # Install the package
  exec { 'install_python_pkg':
    command => "/usr/sbin/installer -pkg ${download_path} -target /",
    unless  => "/usr/bin/python3 --version 2>&1 | /usr/bin/grep -q '3.11'",
    require => Exec['download_python_pkg'],
    path    => ['/usr/bin', '/usr/sbin'],
  }

  # Cleanup the downloaded package file
  file { $download_path:
    ensure  => absent,
    require => Exec['install_python_pkg'],
  }
}
