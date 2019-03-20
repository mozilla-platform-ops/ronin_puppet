# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define packages::macos_package_from_github (
    String $github_repo_slug,
    String $version,
    String $filename,
    String $file_destination = $title,
    Enum['bin', 'pkg', 'dmg'] $type = 'bin',
) {

    require packages::setup

    $release_url = "https://github.com/${github_repo_slug}/releases/download/${version}/${filename}"

    case $type {
        'bin': {
            file { $file_destination:
                ensure => 'file',
                source => $release_url,
                mode   => '0755',
                user   => $::root_user,
                group  => $::root_group,
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
            fail("${module_name} is not supported on ${::operatingsystem}")
        }
    }
}
