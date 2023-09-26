# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_tester::tooltool {
  require win_mozilla_build_tester::install

  $builds         = "${facts['custom_win_systemdrive']}\\builds"
  $tooltool_cache = "${builds}\\tooltool_cache"

  file { $builds:
    ensure => directory,
  }
  file { "${facts['custom_win_systemdrive']}\\mozilla-build\\tooltool.py":
    source => 'https://raw.githubusercontent.com/mozilla-releng/tooltool/master/client/tooltool.py',
  }
  file { $tooltool_cache:
    ensure => directory,
  }

  # Resource from counsyl-windows
  windows::environment { 'TOOLTOOL_CACHE':
    value => $tooltool_cache,
  }
  # Resource from puppetlabs-acl
  acl { "${$facts['custom_win_systemdrive']}\\tooltool-cache":
    target                     => $tooltool_cache,
    permissions                => {
      identity    => 'everyone',
      rights      => ['full'],
      perm_type   => 'allow',
      child_types => 'all',
      affects     => 'all',
    },
    inherit_parent_permissions => true,
  }

  # This script will get the SSL Server Certificate for https://tooltool.mozilla-releng.net
  # and will add it to the local user store
  # Without the cert in the local user store tooltool will hit SSL errors when fetching a package
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1546827
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1548641
  #exec { 'install_tooltool_cert':
  #  command  => file('win_mozilla_build_tester/tooltool_cert_install.ps1'),
  #  provider => powershell,
  #}
}