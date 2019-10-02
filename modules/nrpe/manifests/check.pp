# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# used from nrpe::check::*; do not use directly
define nrpe::check(
    String $cfg          = undef,
    String $nsclient_cfg = undef,
    ) {
    include nrpe::base
    include nrpe::settings
    include users::root

    case $::operatingsystem {
        Darwin: {
            file {
                "${nrpe::settings::nrpe_etcdir}/nrpe.d/${title}.cfg":
                    owner   => $::root_user,
                    group   => $::root_group,
                    notify  => Class['nrpe::service'],
                    content => "command[${title}]=${cfg}\n";
            }
        }
        default: {
            fail("${::operatingsystem} not suported")
        }
    }
}
