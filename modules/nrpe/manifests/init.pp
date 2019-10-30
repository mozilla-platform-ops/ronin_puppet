# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class nrpe (
    String $nrpe_allowed_hosts = '127.0.0.1',
) {

    include nrpe::settings
    include nrpe::service
    include shared

    $plugins_dir = $nrpe::settings::plugins_dir
    $nrpe_etcdir = $nrpe::settings::nrpe_etcdir

    case $facts['os']['name'] {
        'Darwin': {

            include packages::nrpe

            file {
                default: * => $::shared::file_defaults;

                $nrpe_etcdir:
                    ensure  => directory,
                    require => Class['packages::nrpe'];
                "${nrpe_etcdir}/nrpe.cfg":
                    content => template('nrpe/nrpe.cfg.erb'),
                    require => Class['packages::nrpe'],
                    notify  => Class['nrpe::service'];
                "${nrpe_etcdir}/nrpe.d":
                    ensure  => directory,
                    recurse => true,
                    purge   => true,
                    require => Class['packages::nrpe'],
                    notify  => Class['nrpe::service'];
            }
        }
        default: {
            fail("${facts['os']['name']} not suported")
        }
    }
}
