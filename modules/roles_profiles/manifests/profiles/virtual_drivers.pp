# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::virtual_drivers {
  case $facts['os']['name'] {
    'Windows': {
      $version               = lookup(['win-worker.variant.vac.version', 'win-worker.vac.version', 'windows.vac.version'])
      $package               = lookup(['win-worker.variant.vac.package', 'win-worker.vac.package', 'windows.vac.package'], { 'default_value' => "vac${version}.zip" })
      $package_dir           = lookup(['win-worker.variant.vac.package_dir', 'win-worker.vac.package_dir', 'windows.vac.package_dir'], { 'default_value' => "vac${version}" })
      $installer             = lookup(['win-worker.variant.vac.installer', 'win-worker.vac.installer', 'windows.vac.installer'], { 'default_value' => 'setup64.exe' })
      $flags                 = lookup(['win-worker.variant.vac.install_flags', 'win-worker.vac.install_flags', 'windows.vac.install_flags'], { 'default_value' => '-s -k 30570681-0a8b-46e5-8cb2-d835f43af0c5' })
      $install_timeout       = lookup(['win-worker.variant.vac.install_timeout', 'win-worker.vac.install_timeout', 'windows.vac.install_timeout'], { 'default_value' => 1200 })
      $trusted_publisher_cat = lookup(['win-worker.variant.vac.trusted_publisher_cat', 'win-worker.vac.trusted_publisher_cat', 'windows.vac.trusted_publisher_cat'], { 'default_value' => '' })
      $vac_dir               = lookup('windows.dir.vac')
      $work_dir              = "${vac_dir}\\${package_dir}"
      $srcloc                = lookup('windows.ext_pkg_src')

      class { 'win_packages::vac':
        flags                 => $flags,
        installer             => $installer,
        install_timeout       => $install_timeout,
        package               => $package,
        srcloc                => $srcloc,
        trusted_publisher_cat => $trusted_publisher_cat,
        vac_dir               => $vac_dir,
        work_dir              => $work_dir,
      }
      # Bug List
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1656286
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
