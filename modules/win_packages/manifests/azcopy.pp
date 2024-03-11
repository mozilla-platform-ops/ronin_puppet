# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::azcopy (
    String $pkg,
    String $package=$title,
    String $pkgdir = $facts['custom_win_temp_dir']
){

    require win_packages::azcopy_script

    $srcloc = lookup('windows.ext_pkg_src')
    $app_id = lookup('azcopy_app_id')
    $secret = lookup('azcopy_app_client_secret')
    $tenant = lookup('azcopy_tenant_id')
    $azcopy = 'D:\applications\azcopy.ps1'


    exec { "azcopy_${pkg}":
        command  => "${azcopy} -pkg ${pkg}  -pkgdir  ${pkgdir}; if ($\{lastExitCode\} -ne 0) \{ exit 99 \} ",
        provider => powershell,
        creates  => "${pkgdir}\\${pkg}",
    }
}
