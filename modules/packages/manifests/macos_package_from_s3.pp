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

    include packages::settings
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
        true  => $facts['os']['macosx']['version']['major'],
        false => 'common'
    }

    $source = "https://${_s3_domain}/${_bucket}/macos/${p}/${v}/${title}"

    case $type {
        'bin': {
            file { $file_destination:
                ensure         => 'file',
                source         => $source,
                checksum       => 'sha256',
                checksum_value => $checksum,
                mode           => '0755',
                owner          => $packages::settings::root_user,
                group          => $packages::settings::root_group,
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
