# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python2 (
    Pattern[/^\d+\.\d+\.\d+_?\d*$/] $version = '2.7.16',
) {

    # https://www.python.org/ftp/python/2.7.16/python-2.7.16-macosx10.9.pkg
    # c4354a53f4a85c28470d191cc44292f01745984040bc0e8e311894776d0b906c

    packages::macos_package_from_s3 { "python-${version}-macosx10.9.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }

    # Install certifi's set of CAs to override the system set
    exec {
        'install python2 certs':
            command => "\"/Applications/Python ${version[0,3]}/Install Certificates.command\"",
            path    => ['/usr/bin', '/usr/sbin', '/bin'],
            unless  => "test -L /Library/Frameworks/Python.framework/Versions/${version[0,3]}/etc/openssl/cert.pem",
    }
}
