# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3 (
  Pattern[/^\d+\.\d+\.\d+_?\d*$/] $version = '3.7.4',
  String $certifi_version = '2026.10.19',
  String $certifi_wheel_url = 'https://files.pythonhosted.org/packages/c4/51/29046e48f693c54e5b7412216d447a1d8362c9653148d98c02cdf65fa733/certifi-2026.10.19-py3-none-any.whl',
  String $certifi_sha256 = '42d35340cc5b9ba78e818ddbff0c5b1c2b779de448a340fd1b989f5fa8670e1b',
) {
#    # As of puppet 7.0.0, facts.os.architecture still reports the M1 arm64 hardware as x86_64
#    # therfore, we check the mac model instead
#    if $facts['system_profiler']['model_identifier'] == 'Macmini9,1' {
#        $pkg_name = "python-${version}-macos11.0.pkg"
#    } else {
#        $pkg_name = "python-${version}-macosx10.9.pkg"
#    }

  $split_arr = split(String($version), '[.]')
  $short_version = $split_arr[0,2].join('.')

  $pkg_name = "python-${version}-macosx10.9.pkg"
  packages::macos_package_from_s3 { $pkg_name:
    private             => false,
    os_version_specific => false,
    type                => 'pkg',
  }

  # Install certifi's set of CAs to override the system set
  exec {
    'install python3 certs':
      command => "\"/Applications/Python ${short_version}/Install Certificates.command\"",
      path    => ['/usr/bin', '/usr/sbin', '/bin'],
      unless  => "test -L /Library/Frameworks/Python.framework/Versions/${short_version}/etc/openssl/cert.pem",
      require => Packages::Macos_package_from_s3[$pkg_name],
  }

  # The certs command above only runs once, so the framework's openssl
  # cert.pem stays at whatever certifi was current at provision time.
  # Pin certifi so CA removals actually reach the fleet. The internal
  # mirror in the global pip.conf lags PyPI, so skip pip config and
  # install the hash-pinned wheel directly.
  $framework_bin = "/Library/Frameworks/Python.framework/Versions/${short_version}/bin"
  exec { 'pin python3 certifi':
    command     => "${framework_bin}/python3 -m pip install --disable-pip-version-check '${certifi_wheel_url}#sha256=${certifi_sha256}'",
    unless      => "${framework_bin}/python3 -c 'import certifi; assert certifi.__version__ == \"${certifi_version}\"'",
    environment => ['PIP_CONFIG_FILE=/dev/null'],
    path        => [$framework_bin, '/usr/bin', '/bin'],
    timeout     => 300,
    require     => Exec['install python3 certs'],
  }
}
