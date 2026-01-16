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
        ## WIP for RELOPS-1946
        ## Not currently working. Leaving n place for ref.
        #include win_disable_services::disable_defender_smartscreen
        #include win_disable_services::disable_sync_from_cloud
        if $facts['custom_win_release_id'] == '2004' or '2009' {
          ## win11 ref with osdcloud
          include win_disable_services::disable_windows_defender_schtask
        }
        case $facts['custom_win_location'] {
            'datacenter': {
                $apx_uninstall = 'hw-uninstall.ps1'
                include win_disable_services::disable_optional_services
                include win_disable_services::disable_ms_edge
            }
            'azure': {
                include win_scheduled_tasks::kill_local_clipboard
                $apx_uninstall = 'uninstall.ps1'
            }
            default: {
            }
        }
        ## Let's Uninstall Appx Packages
        ## Taken from https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool
        ## Bug 1913499 https://bugzilla.mozilla.org/show_bug.cgi?id=1913499
        class { 'win_disable_services::uninstall_appx_packages':
            apx_uninstall => $apx_uninstall
        }
      }
      # May be needed for non-hardaware
      # Commented out because this will break the auto restore
      # include win_disable_services::disable_vss
      # include win_disable_services::disable_system_restore
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
