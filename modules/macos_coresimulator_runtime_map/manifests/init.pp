# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @summary
#   Ensures Apple's CoreSimulator RuntimeMap override (iphoneos26.2 ->
#   runtime build 23D8133) is in every generic-worker task user's home
#   directory.
#
#   Xcode 26.2 / 26.3 ships the iphoneos26.2 SDK paired with iOS
#   simulator runtime build 23C57, which Apple no longer serves. Only
#   23D8133 (iOS 26.3.1) is downloadable via `xcodebuild
#   -downloadPlatform iOS`. Without an override, ibtool refuses to
#   compile the LaunchScreen storyboard during build-ios-arm64/debug:
#
#     error: iOS 26.2 Platform Not Installed.
#
#   CoreSimulator reads its override map strictly from
#   ~/Library/Developer/CoreSimulator/RuntimeMap.plist; the
#   /Library/Developer/CoreSimulator/... path is ignored. Because
#   generic-worker-multiuser creates a fresh task_<id> user per task,
#   we keep the canonical file under /Library/... and use a LaunchDaemon
#   triggered on /Users/ changes to copy it into each new task user's
#   home before the build runs.
#
class macos_coresimulator_runtime_map (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['name'] {
      'Darwin': {
        $sync_script        = '/usr/local/bin/coresim_runtimemap_sync.sh'
        $launchdaemon_plist = '/Library/LaunchDaemons/com.mozilla.coresim-runtimemap-sync.plist'

        file { '/Library/Developer/CoreSimulator':
          ensure => 'directory',
          owner  => 'root',
          group  => 'wheel',
          mode   => '0755',
        }

        file { '/Library/Developer/CoreSimulator/RuntimeMap.plist':
          ensure  => 'file',
          content => file('macos_coresimulator_runtime_map/RuntimeMap.plist'),
          owner   => 'root',
          group   => 'wheel',
          mode    => '0644',
          require => File['/Library/Developer/CoreSimulator'],
        }

        file { $sync_script:
          ensure => 'file',
          source => 'puppet:///modules/macos_coresimulator_runtime_map/coresim_runtimemap_sync.sh',
          owner  => 'root',
          group  => 'wheel',
          mode   => '0755',
        }

        file { $launchdaemon_plist:
          ensure  => 'file',
          source  => 'puppet:///modules/macos_coresimulator_runtime_map/com.mozilla.coresim-runtimemap-sync.plist',
          owner   => 'root',
          group   => 'wheel',
          mode    => '0644',
          require => [
            File[$sync_script],
            File['/Library/Developer/CoreSimulator/RuntimeMap.plist'],
          ],
          notify  => Exec['load coresim-runtimemap-sync launchdaemon'],
        }

        exec { 'load coresim-runtimemap-sync launchdaemon':
          command     => "/bin/launchctl bootstrap system ${launchdaemon_plist}",
          unless      => '/bin/launchctl print system/com.mozilla.coresim-runtimemap-sync',
          path        => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
          require     => File[$launchdaemon_plist],
          refreshonly => false,
        }
      }
      default: {
        fail("${module_name} does not support ${facts['os']['name']}")
      }
    }
  }
}
