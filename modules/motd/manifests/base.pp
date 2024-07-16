# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class motd::base {
    include motd::settings

    $group = $facts['os']['name'] ? {
        'Darwin' => 'wheel',
        default  => 'root'
    }
    concat { $motd::settings::motd_file:
            owner => 'root',
            group => $group,
            mode  => '0644';
    }
    # need at least one fragment, or concat will fail:
    concat::fragment { 'base-motd':
        target  => $motd::settings::motd_file,
        content => "
    ┌───┬──┐                         _ _ _
    │ ╷╭╯╷ │                       (_) | |
    │  └╮  │     _ __ ___   ___ _____| | | __ _
    │ ╰─┼╯ │    | '_ ` _ \\ / _ \\_  / | | |/ _` |
    └───┴──┘    | | | | | | (_) / /| | | | (_| |
                |_| |_| |_|\\___/___|_|_|_|\\__,_|

Unauthorized access prohibited
        "
    }
}
