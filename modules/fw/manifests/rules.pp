# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define fw::rules (
    Array   $sources,
    String  $app,
    Boolean $log = false,
) {

    include fw::apps

    $proto = $::fw::apps::app_proto_port[$app]['proto']
    $port  = $::fw::apps::app_proto_port[$app]['port']

    $sources_uniq = unique(flatten($sources))
    $rules = suffix($sources_uniq, " ${proto}/${port} ${name}")

    case $facts['kernel'] {
        'Darwin': {
            fw::pf_rule { $name:
                sources => $sources_uniq,
                proto   => $proto,
                port    => $port,
                log     => $log,
            }
        }
        default: {
            fail("This ${facts['os']['name']} is not supported")
        }
    }

}
