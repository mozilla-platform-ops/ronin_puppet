# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::pulseaudio {
  # Ensure the 'ulseaudio-utils' package is installed which provides pactl
  package { 'pulseaudio-utils':
    ensure   => installed,
    name     => 'pulseaudio-utils',
    provider => 'apt',
  }
}
