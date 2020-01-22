# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define packages::linux_package_from_s3 (
    Optional[String] $bucket                     = undef,
    Optional[String] $s3_domain                  = undef,
    Boolean $private                             = false,
    Boolean $os_version_specific                 = true,
    Enum['deb'] $type    = 'bin',
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
        'deb': {
            # Install dmg or pkg
            package { $title:
                    ensure   => 'installed',
                    provider => 'apt',
                    source   => $source,
            }
        }
        default: {
            fail("${type} is not supported")
        }
    }
}
