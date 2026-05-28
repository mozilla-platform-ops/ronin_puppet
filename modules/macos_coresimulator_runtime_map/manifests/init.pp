# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @summary
#   Drops /Library/Developer/CoreSimulator/RuntimeMap.plist with an iOS SDK
#   build -> simulator runtime build override.
#
#   Xcode 26.2/26.3 ships with the iphoneos26.2 SDK whose paired runtime build
#   (23C57) Apple no longer serves; only the newer 23D8133 (iOS 26.3.1) runtime
#   is downloadable via `xcodebuild -downloadPlatform iOS`. Without the
#   override, ibtool refuses to compile storyboards with
#   "iOS 26.2 Platform Not Installed".
#
#   This file is the equivalent of running:
#     xcrun simctl runtime match set iphoneos26.2 23D8133
#   ...but placed at the system path so it applies to the ephemeral per-task
#   users that generic-worker-multiuser spawns for builds.
#
class macos_coresimulator_runtime_map (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['name'] {
      'Darwin': {
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
      }
      default: {
        fail("${module_name} does not support ${facts['os']['name']}")
      }
    }
  }
}
