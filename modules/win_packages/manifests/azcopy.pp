# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::azcopy (
    String $pkg,
    String $package=$title,
    String $pkgdir = $facts['custom_win_temp_dir']
){

    $srcloc = lookup('windows.ext_pkg_src')
    $app_id = lookup('azcopy.app_id', String)
    $secret = lookup('azcopy.app_client_secret', String)
    $tenant = lookup('azcopy.tenant_id', String)
    $azcopy = 'D:\applications\azcopy.exe'

    windows::environment { 'AZCOPY_SPA_APPLICATION_ID':
        value => $app_id,
    }
    windows::environment { 'AZCOPY_SPA_CLIENT_SECRET':
        value => $secret,
    }
    windows::environment { 'AZCOPY_TENANT_ID':
        value => $tenant,
    }

    exec { "azcopy_${pkg}":
        command  => "${azcopy} copy ${srcloc}/${pkg} ${pkgdir}\\${pkg}",
        provider => powershell,
        creates  => "${pkgdir}\\${pkg}",
    }
}
