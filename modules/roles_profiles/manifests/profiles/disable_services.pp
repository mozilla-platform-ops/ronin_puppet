# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::disable_services {

    case $::operatingsystem {
        'Darwin': {
            service {
                [ 'com.apple.apsd',
                  'com.apple.systemstats.daily',
                  'com.apple.systemstats.analysis',
                  'com.apple.metadata.mds',
                  'com.apple.metadata.mds.index',
                  'com.apple.metadata.mds.scan',
                  'com.apple.metadata.mds.spindump', ]:
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
            if $facts['os']['release']['full'] != '2012 R2' {
                include win_disable_services::disable_wsearch
                if ($facts['custom_win_location'] == 'azure') {
                    include win_scheduled_tasks::kill_local_clipboard
                }
              if $facts['custom_win_release_id'] == '1903' or '2004'{
                  include win_disable_services::disable_windows_defender_schtask
              } else {
                  include win_disable_services::disable_windows_defender
              }
            }
            if $facts['os']['release']['full'] == '10' {
                include win_disable_services::disable_onedrive
            }
            # May be needed for non-hardaware
            # Commented out because this will break the auto restore
            # include win_disable_services::disable_vss
            # include win_disable_services::disable_system_restore
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }


}
