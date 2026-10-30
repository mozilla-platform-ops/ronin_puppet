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
          ## win11 ref with osdcloud
          include win_disable_services::disable_windows_defender_schtask
        }
        case $facts['custom_win_location'] {
          'datacenter': {
            include win_disable_services::disable_optional_services
            # Disable Windows Defender real-time/on-access scanning on the
            # datacenter hardware fleet explicitly. Do NOT rely on the
            # custom_win_release_id in ['2004','2009'] gate above: Win11 freezes
            # ReleaseId at 2009 (DisplayVersion carries 24H2), so that branch
            # only fires by coincidence and would silently stop disabling
            # Defender if the reported ReleaseId ever changed. Including the
            # class is idempotent, so this is harmless where the gate also fires.
            # Tamper Protection is enforced on this fleet (TamperProtectionSource=5),
            # so Set-MpPreference / policy DisableRealtimeMonitoring do not stick;
            # the schtask renames the WdFilter/WdBoot/WdNisDrv drivers at boot,
            # which works below Tamper Protection. State is asserted by the
            # win_nsclient check_defender check.
            include win_disable_services::disable_windows_defender_schtask
            # Declare the policy/passive/real-time-off intent. Ignored while Tamper
            # Protection is on (the schtask rename is what works there), but correct
            # and immediate on any Tamper-off image.
            include win_disable_services::disable_windows_defender
          }
          'azure': {
            $apx_uninstall = 'uninstall.ps1'
            class { 'win_disable_services::uninstall_appx_packages':
              apx_uninstall => $apx_uninstall,
            }
            include win_scheduled_tasks::kill_local_clipboard
            include win_disable_services::disable_onedrive_setup
            ## Disable Unnecessary tasks
            ## Taken from https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool
            ## Bug 1913499 https://bugzilla.mozilla.org/show_bug.cgi?id=1913499
            include win_disable_services::disable_scheduled_tasks
          }
          default: {
          }
        }
        ## Let's Uninstall Appx Packages
        ## Taken from https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool
        ## Bug 1913499 https://bugzilla.mozilla.org/show_bug.cgi?id=1913499
        ## must be ran after apx uninstall
        if ($facts['custom_win_location'] == 'datacenter') {
          include win_disable_services::disable_ms_edge
          include win_disable_services::disable_defender_smartscreen
          include win_disable_services::extended_uninstall_appx_packages
          ## Can't disable appxsvc on ref hardware as it will affect the task
          ## user's ability to use codecs
          ## Ref: https://bugzilla.mozilla.org/show_bug.cgi?id=2013985
          ##
          ## The bake DOES disable it (deliberately - see below), so declining to disable at
          ## deploy time is not enough on a pre-baked WIM: the image arrives with AppXSvc
          ## Start=4 plus the \Hardening\Hard-Disable-AppXSvc startup task, and nothing ever
          ## undoes them. ref/ref-alpha therefore need an ACTIVE re-enable, not an exemption.
          ##
          ## Staging vs registration: the HEVC/AV1/VP9/WebMedia packages are PROVISIONED into
          ## the image at bake time, which is DISM-level and needs no AppXSvc. Only the
          ## per-user registration that happens when a task_* user first logs on needs the
          ## service running. So the split is: stage at bake, register at deploy. RELOPS-2487.
          if $facts['custom_win_worker_pool_id'] == 'win11-64-24h2-hw-ref-alpha' or
              $facts['custom_win_worker_pool_id'] == 'win11-64-24h2-hw-ref' {
            include win_disable_services::enable_appxsvc
          }
          else {
            include win_disable_services::disable_appxsvc
          }
        }
      }

      # Do not disable VSS or System Restore. This breaks automatic restore.
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
