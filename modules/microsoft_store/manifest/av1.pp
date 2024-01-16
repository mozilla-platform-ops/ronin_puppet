# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class microsoft_store::av1 {
  require microsoft_store::init
  ## Puppet functions fails to apply without a reboot, hence the powershell exec step below
  exec { 'microsoft_store':
    command  => file('microsoft_store/install.ps1'),
    onlyif   => file('microsoft_store/validate.ps1'),
    provider => powershell,
    timeout  => 300,
  }
}
