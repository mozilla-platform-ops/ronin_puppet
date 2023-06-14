# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class dirs::builds {

    $builds_dir = $facts['os']['macosx']['version']['major'] ? {
        '13' => '/opt/builds',
        '11' => '/opt/builds',
        '10.15' => '/builds',
        default => '/opt/builds'
    }

    file { $builds_dir:
        ensure => directory,
        mode   => '0755',
    }
}
