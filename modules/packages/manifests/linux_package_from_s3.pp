# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define packages::linux_package_from_s3 (
    Optional[String] $bucket                     = undef,
    Optional[String] $s3_domain                  = undef,
    Optional[String] $file_destination           = undef,
    Optional[String] $checksum                   = undef,
    Boolean $private                             = false,
    Boolean $os_version_specific                 = true,
    Enum['deb', 'bin'] $type    = 'bin',
) {

    include shared
    require packages::setup

    $_bucket = $bucket ? { true => $bucket, default => $packages::setup::default_bucket }
    $_s3_domain = $s3_domain ? { true => $s3_domain, default => $packages::setup::default_s3_domain }

    # Set path private or public
    $p = $private ? {
        true  => 'private',
        false => 'public'
    }

    # Set path os specific version or common
    $v = $os_version_specific ? {
        true  => $facts['os']['distro']['release']['major'],
        false => 'common'
    }

    $source = "https://${_s3_domain}/${_bucket}/linux/${p}/${v}/${title}"

    case $type {
        'bin': {
            file {
                default: * => $::shared::file_defaults;

                $file_destination:
                    ensure         => 'file',
                    source         => $source,
                    checksum       => 'sha256',
                    checksum_value => $checksum,
                    mode           => '0755';
            }
        }
        'deb': {
            # package with provider apt won't install from an url or a local file.
            # we're forced to fetch file, install with dpkg, then fix deps with apt.

            $destination = "/tmp/${title}"

            file {
                default: * => $::shared::file_defaults;

                $destination:
                  ensure         => 'file',
                  source         => $source,
                  checksum       => 'sha256',
                  checksum_value => $checksum,
                  mode           => '0644';
            }

            exec { 'install package':
                command => "/usr/bin/apt install -f ${destination} -y",
                # TODO: figure out an unless condition
            }
        }
        default: {
            fail("${type} is not supported")
        }
    }
}
