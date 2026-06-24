# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::win116424h2azure {
  class { 'roles_profiles::roles::win1164h2azure':
    gpu_driver => 'gpu',
  }
}
