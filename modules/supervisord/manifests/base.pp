# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# NB: This is specific to supervisord version 2
class supervisord::base {
    contain packages::supervisor

    file {
        '/usr/local/etc/supervisor.d':
            ensure  => directory,
            notify  => Service['supervisord'],
            recurse => true,
            purge   => true;
    }

    service {
        'supervisord':
            ensure  => running,
            require => [
                Class['packages::supervisor'],
                File['/usr/local/etc/supervisor.d'],
            ],
            restart => '/usr/bin/supervisorctl reload',
            start   => 'brew services start supervisor',
            stop    => 'brew services stop supervisor',
    }
}
