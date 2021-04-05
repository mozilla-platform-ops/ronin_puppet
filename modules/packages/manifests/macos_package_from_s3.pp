# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define packages::macos_package_from_s3 (
    Optional[String] $bucket                     = undef,
    Optional[String] $s3_domain                  = undef,
    Optional[String] $file_destination           = undef,
    Optional[String] $checksum                   = undef,
    Boolean $private                             = false,
    Boolean $os_version_specific                 = true,
    Enum['bin', 'pkg', 'dmg', 'appdmg'] $type    = 'bin',
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

    # Starting with MacOS Bigsur 11.0.0, the OS versioning scheme changed to where the first int now changes with
    # each MacOS major version release.  This means that minor version changes in the increment the second and third
    # int.  eg. in Catalina, minor versions would increment 10.15.0 -> 10.15.1 -> 10.15.2
    # With Bigsur it now increments 11.0.0 -> 11.1.0 -> 11.2.4.  This seems to indicate the next major MacOS release
    # will be 12.0.0.
    $real_major_version = split($facts['os']['macosx']['version']['major'], '[.]')[0]
    $os_ver = $real_major_version ? {
        '10'    => $facts['os']['macosx']['version']['major'],
        '11'    => '11.0',
        default => $real_major_version
    }

    # Set path os specific version or common
    $v = $os_version_specific ? {
        true  => $os_ver,
        false => 'common'
    }

    $source = "https://${_s3_domain}/${_bucket}/macos/${p}/${v}/${title}"

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
        'pkg','dmg': {
            # Install dmg or pkg
            package { $title:
                    ensure   => 'installed',
                    provider => 'pkgdmg',
                    source   => $source,
            }
        }
        'appdmg': {
            # Install dmg with an app folder inside
            package { $title:
                    ensure   => 'installed',
                    provider => 'appdmg',
                    source   => $source,
            }
        }
        default: {
            fail("${type} is not supported")
        }
    }
}
