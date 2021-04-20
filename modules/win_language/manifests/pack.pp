# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_language::pack (
  String $pack
) {

  exec { 'install_pack':
    provider => powershell,
    command  => epp('win_language/install_language_pack.ps1.epp'),
    }
}
