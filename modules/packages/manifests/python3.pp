# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3 (
  Pattern[/^\d+\.\d+\.\d+_?\d*$/] $version = '3.7.4',
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
}
