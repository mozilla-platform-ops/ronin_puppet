# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vc_redist_2022_x86 {
  if $facts['os']['name'] == 'Windows' {
    $pkg             = 'VC_redist.x86.14.44.35211.0.exe'
    $pkgdir          = $facts['custom_win_temp_dir']
    $srcloc          = lookup('windows.ext_pkg_src')
    $installed_check = "${pkgdir}\\vc_redist_2022_installed.ps1"
    $powershell      = "${facts['custom_win_systemdrive']}\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"

    file { $installed_check:
      ensure => file,
      source => 'puppet:///modules/win_packages/vc_redist_2022_installed.ps1',
    }

    archive { 'vc_redist_2022_x86':
      ensure  => 'present',
      source  => "${srcloc}/${pkg}",
      path    => "${pkgdir}\\${pkg}",
      creates => "${pkgdir}\\${pkg}",
      cleanup => false,
      extract => false,
    }

    exec { 'vc_redist_2022_x86install':
      command => "${pkgdir}\\${pkg} /install /passive /norestart /log ${facts['custom_win_roninlogdir']}\\vc_redist_2022_x86-install.log",
      unless  => "${powershell} -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ${installed_check} -Arch x86",
      returns => [0, 3010],
      timeout => 600,
      require => [
        File[$installed_check],
        Archive['vc_redist_2022_x86'],
      ],
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
