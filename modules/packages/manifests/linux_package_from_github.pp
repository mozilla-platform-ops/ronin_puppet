# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define packages::linux_package_from_github (
    String $github_repo_slug,
    String $version,
    String $filename,
    String $file_destination = $title,
    Enum['bin', 'deb'] $type = 'bin',
) {

    include shared
    require packages::setup

    $release_url = "https://github.com/${github_repo_slug}/releases/download/${version}/${filename}"

    case $type {
        'bin': {
            archive { "fetch ${release_url}":
                    source => $release_url,
                    path   => $file_destination
            }

            file {
                default: * => $::shared::file_defaults;

                "change perms on ${file_destination}":
                    ensure => 'file',
                    path   => $file_destination,
                    mode   => '0755';
            }
        }
        'deb': {
            package { $title:
                    ensure   => 'installed',
                    provider => 'apt',
                    source   => $release_url,
            }
        }
        default: {
            fail("${type} is not supported")
        }
    }
}
