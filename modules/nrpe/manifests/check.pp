# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# used from nrpe::check::*; do not use directly

define nrpe::check (
    String $cfg,
){

    include nrpe::settings
    include shared

    case $facts['os']['name'] {
        'Darwin': {
            file {
                default: * => $::shared::file_defaults;

                "${nrpe::settings::nrpe_etcdir}/nrpe.d/${title}.cfg":
                    notify  => Class['nrpe::service'],
                    content => "command[${title}]=${cfg}\n";
            }
        }
        default: {
            fail("${facts['os']['name']} not suported")
        }
    }
}
