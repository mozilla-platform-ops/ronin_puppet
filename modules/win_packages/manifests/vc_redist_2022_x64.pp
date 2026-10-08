# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vc_redist_2022_x64 {
  if $facts['os']['name'] == 'Windows' {
    include win_packages::staging
    #require win_packages::vc_redist_x86
    require win_packages::vc_redist_2022_x86
    $pkg             = 'VC_redist.x64.14.44.35211.0.exe'
    $pkgdir          = $win_packages::staging::path
    $pkgpath         = "${pkgdir}\\${pkg}"
    $srcloc          = lookup('windows.ext_pkg_src')
    $installed_check = "${pkgdir}\\vc_redist_2022_installed.ps1"
    $powershell      = "${facts['custom_win_systemdrive']}\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"

    archive { 'vc_redist_2022_x64':
      ensure  => 'present',
      source  => "${srcloc}/${pkg}",
      path    => $pkgpath,
      creates => $pkgpath,
      cleanup => false,
      extract => false,
      require => [Class['win_packages::vc_redist_2022_x86'], Class['win_packages::staging']],
    }

    acl { $pkgpath:
      owner                      => 'S-1-5-18',
      inherit_parent_permissions => false,
      purge                      => true,
      permissions                => [
        { identity => 'S-1-5-18', rights => ['full'] },
        { identity => 'S-1-5-32-544', rights => ['full'] },
        { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
      ],
      require                    => Archive['vc_redist_2022_x64'],
    }

    exec { 'vc_redist_2022_x64install':
      command => "${pkgpath} /install /passive /norestart /log ${facts['custom_win_roninlogdir']}\\vc_redist_2022_x64-install.log",
      unless  => "${powershell} -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ${installed_check} -Arch x64",
      returns => [0, 3010],
      timeout => 600,
      require => [
        Acl[$installed_check],
        Acl[$pkgpath],
      ],
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
