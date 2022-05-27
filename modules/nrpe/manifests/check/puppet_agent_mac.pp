# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class nrpe::check::puppet_agent_mac {
    include nrpe::settings
    $plugins_dir = $nrpe::settings::plugins_dir

    $statefile = '/opt/puppetlabs/puppet/cache/state/last_run_summary.yaml'

    nrpe::check {
        'check_puppet_agent':
            cfg => "${plugins_dir}/check_puppet_agent -w \$ARG1\$ -c \$ARG2\$ -s ${statefile}";
    }

    nrpe::plugin {
        'check_puppet_agent': ;
    }
}
