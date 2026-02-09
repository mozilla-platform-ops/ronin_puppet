# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::disable_services {
  case $facts['os']['name'] {
    'Darwin': {
      service {
        ['com.apple.apsd',
          'com.apple.systemstats.daily',
          'com.apple.systemstats.analysis',
          'com.apple.metadata.mds',
          'com.apple.metadata.mds.index',
          'com.apple.metadata.mds.scan',
        'com.apple.metadata.mds.spindump',]:
          ensure => 'stopped',
          enable => false,
      }

      exec {
        'disable-indexing':
          command     => '/usr/bin/mdutil -a -i off',
          refreshonly => true;
        'remove-index':
          command     => '/usr/bin/mdutil -a -E',
          refreshonly => true;
      }

      file { '/var/db/.spotlight-indexing-disabled':
        content => 'indexing-disabled',
        notify  => Exec['disable-indexing', 'remove-index'],
      }

      include macos_mobileconfig_profiles::disable_diagnostic_submissions
      include macos_mobileconfig_profiles::disable_gatekeeper
    }
    'Windows': {
      include win_disable_services::disable_puppet
      include win_disable_services::disable_windows_update
      if $facts['custom_win_purpose'] != builder {
        include win_disable_services::disable_wsearch
        if $facts['custom_win_release_id'] in ['2004', '2009'] {
          include win_disable_services::disable_windows_defender_schtask
        }
        case $facts['custom_win_location'] {
          'datacenter': {
            class { 'win_disable_services::uninstall_appx_packages':
              apx_uninstall => 'hw-uninstall.ps1',
            }
            include win_disable_services::disable_optional_services
            include win_disable_services::disable_ms_edge
          }
          'azure': {
            class { 'win_disable_services::uninstall_appx_packages':
              apx_uninstall => 'uninstall.ps1',
            }
            include win_scheduled_tasks::kill_local_clipboard
            ## Bug 1913499
            include win_disable_services::disable_scheduled_tasks
          }
          default: {}
        }
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
