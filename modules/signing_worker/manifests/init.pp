# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker (
    String $user = 'cltbld',
    String $group = 'staff',
    String $scriptworker_base = '/builds/scriptworker',
    String $dmg_prefix = 'prod',
    String $worker_id_suffix = '',
    String $cot_product = 'firefox',
) {
    include signing_worker::base
}
