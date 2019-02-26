# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service::grant_registry_access {

require win_mozilla_maintenance_service::install

    reg_acl { $win_mozilla_maintenance_service::short_maintence_key:
        permissions =>
            [
                {'RegistryRights' => 'FullControl', 'IdentityReference' => 'Everyone'},
            ],
    }
}
