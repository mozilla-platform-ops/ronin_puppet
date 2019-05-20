# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker (
    String $user = 'cltbld',
    String $group = 'staff',
    String $virtualenv_dir = '/Users/cltbld/virtualenv',
    String $tmp_requirements = '/Users/cltbld/requirements.txt',
    String $config_file = '/Users/cltbld/scriptworker_config.json'
) {
    include signing_worker::base
}
