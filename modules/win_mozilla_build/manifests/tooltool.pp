# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## CLEAN UP: tootool support is no longer needed

class win_mozilla_build::tooltool {
  require win_mozilla_build::install

  $builds         = "${facts['custom_win_systemdrive']}\\builds"
  $tooltool_cache = "${builds}\\tooltool_cache"
  $tooltool_dst = "${facts['custom_win_systemdrive']}\\mozilla-build\\tooltool.py"
  $tooltool_src = 'https://raw.githubusercontent.com/mozilla-releng/tooltool/master/client/tooltool.py'
  $tooltool_ps1 = "${facts['custom_win_roninprogramdata']}\\download_tooltool.ps1"
  $github_pat = $facts['custom_win_github_pat']

  ## If we're running in datacenter, use github pat
  case $facts['custom_win_location'] {
    'azure': {
      file { $tooltool_dst:
        source => 'https://raw.githubusercontent.com/mozilla-releng/tooltool/master/client/tooltool.py',
      }
    }
    'datacenter': {
      file { $tooltool_ps1:
        ensure  => file,
        content => epp('win_mozilla_build/download_tooltool.ps1.epp', {
            'url'  => $tooltool_src,
            'path' => $tooltool_dst,
            'pat'  => $github_pat,
        }),
      }

      exec { 'download_tooltool':
        provider => powershell,
        command  => $tooltool_ps1,
        require  => File[$tooltool_ps1],
      }
    }
    default: {
      fail('custom_win_location not supported')
    }
  }

  file { $builds:
    ensure => directory,
  }

  file { $tooltool_cache:
    ensure => directory,
  }

  windows::environment { 'TOOLTOOL_CACHE':
    value => $tooltool_cache,
  }

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

  case lookup('win-worker.function') {
    'builder': {
      # This script will get the SSL Server Certificate for https://tooltool.mozilla-releng.net
      # and will add it to the local user store
      # Without the cert in the local user store tooltool will hit SSL errors when fetching a package
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1546827
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1548641
      exec { 'install_tooltool_cert':
        command  => file('win_mozilla_build/tooltool_cert_install.ps1'),
        provider => powershell,
      }
    }
    'tester': {
      notice('No further tooltool modifications for testers')
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
