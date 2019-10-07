# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This resource is broken because github releases use presigned S3 URIs which puppet can't handle.
# In the meantime, copy releases from github to relops managed amazon s3 bucket and use macos_package_from_s3 resource
#
# https://tickets.puppetlabs.com/browse/PUP-8300
# https://tickets.puppetlabs.com/browse/PUP-6380
# https://github.com/puppetlabs/puppet/pull/5002
# https://github.com/puppetlabs/puppet/pull/7051

define packages::macos_package_from_github (
    String $github_repo_slug,
    String $version,
    String $filename,
    String $file_destination = $title,
    Enum['bin', 'pkg', 'dmg'] $type = 'bin',
) {

    include shared
    require packages::setup

    $release_url = "https://github.com/${github_repo_slug}/releases/download/${version}/${filename}"

    case $type {
        'bin': {
            file {
                default: * => $::shared::file_defaults;

                $file_destination:
                    ensure => 'file',
                    source => $release_url,
                    mode   => '0755';
            }
        }
        'pkg','dmg': {
            # Install dmg or pkg
            package { $title:
                    ensure   => 'installed',
                    provider => 'pkgdmg',
                    source   => $release_url,
            }
        }
        default: {
            fail("${type} is not supported")
        }
    }
}
