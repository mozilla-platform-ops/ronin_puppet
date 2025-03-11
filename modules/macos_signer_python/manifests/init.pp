class macos_signer_python (
  Boolean $enabled = true,
) {
  $pkg_url    = 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/macos/public/common/python-3.11-macosx10.9.pkg'
  $pkg_name   = 'python-3.11-macosx10.9.pkg'
  $download_path = "/tmp/${pkg_name}"

  # Ensure the required package is downloaded
  exec { 'download_python_pkg':
    command => "curl -o ${download_path} ${pkg_url}",
    creates => $download_path,
    path    => ['/usr/bin', '/usr/sbin', '/bin'],
  }

  # Install the package
  exec { 'install_python_pkg':
    command => "/usr/sbin/installer -pkg ${download_path} -target /",
    unless  => "test -L /usr/local/bin/python3 && /usr/local/bin/python3 --version 2>&1 | grep -q '3.11'",
    require => Exec['download_python_pkg'],
    path    => ['/usr/bin', '/usr/sbin', '/bin'],
  }

  # Install certifi's set of CAs to override the system set
  exec {
    'install python3 certificates':
      command => "\"/Applications/Python 3.11/Install Certificates.command\"",
      path    => ['/usr/bin', '/usr/sbin', '/bin'],
      unless  => 'test -L /Library/Frameworks/Python.framework/Versions/3.11/etc/openssl/cert.pem',
      require => Exec['install_python_pkg'],
  }
}
