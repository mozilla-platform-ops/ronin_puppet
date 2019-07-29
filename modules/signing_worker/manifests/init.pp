# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker (
    String $user = 'cltbld',
    String $group = 'staff',
    String $virtualenv_dir = '/builds/scriptworker/virtualenv',
    String $tmp_requirements = '/Users/cltbld/requirements.txt',
    String $scriptworker_config_file = '/builds/scriptworker/scriptworker.yaml',
    String $script_config_file = '/builds/scriptworker/script_config.yaml',
) {
    include signing_worker::base
}
