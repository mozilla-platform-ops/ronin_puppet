# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::custom_nssm (
    String $version,
    String $nssm_dir,
    String $nssm_exe
) {
    $version_dir = "${nssm_dir}\\nssm-${version}"
    $arch_dir    = "${version_dir}\\win64"

    win_packages::win_zip_pkg { "nssm-${version}":
        pkg         => "nssm-${version}.zip",
        creates     => $nssm_exe,
        destination => $nssm_dir,
    }

    acl { $nssm_dir:
        owner                      => 'S-1-5-18',
        inherit_parent_permissions => false,
        purge                      => true,
        permissions                => [
            { identity => 'S-1-5-18', rights => ['full'] },
            { identity => 'S-1-5-32-544', rights => ['full'] },
            { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
        ],
        require                    => File[$nssm_dir],
    }
    Acl[$nssm_dir] -> Exec["nssm-${version}.zip"]

    acl { [$version_dir, $arch_dir, $nssm_exe]:
        owner                      => 'S-1-5-18',
        inherit_parent_permissions => false,
        purge                      => true,
        permissions                => [
            { identity => 'S-1-5-18', rights => ['full'] },
            { identity => 'S-1-5-32-544', rights => ['full'] },
            { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
        ],
        require                    => Exec["nssm-${version}.zip"],
    }
}
