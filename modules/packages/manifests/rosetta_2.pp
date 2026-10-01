# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Ensure Rosetta 2 is installed on Apple Silicon.
#
# Test packages still ship x86_64 helpers -- certutil at minimum -- so without
# Rosetta a task dies before running a single test:
#   OSError: [Errno 86] Bad CPU type in executable: '.../tests/bin/certutil'
# An in-place macOS upgrade removes Rosetta and nothing reinstalls it: after
# macmini-m4-130/131 went 26 -> 27 it was simply gone (no oah runtime, no
# RosettaUpdateAuto receipt) and 11 of 85 test tasks failed that way.
#
# Guarded on the runtime itself. The old guard, com.apple.oahd.plist under
# /Library/Apple/System/Library/LaunchDaemons, does not exist on macOS 27 even
# with Rosetta installed, so it would have re-run the installer on every apply.
# No-op on Intel, where Rosetta does not apply.
class packages::rosetta_2 {
  if $facts['os']['architecture'] == 'arm64' {
    exec { 'install_rosetta_2':
      command => '/usr/sbin/softwareupdate --install-rosetta --agree-to-license',
      creates => '/Library/Apple/usr/libexec/oah/libRosettaRuntime',
      timeout => 900,
    }
  }
}
