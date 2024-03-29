# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class dirs::tools {

    $tools_dir = $facts['os']['macosx']['version']['major'] ? {
        '10.15' => '/tools',
        default => '/opt/tools'
    }

    file { $tools_dir:
        ensure => directory,
        mode   => '0755',
    }
}
