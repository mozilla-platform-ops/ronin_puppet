# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This class provides a utility to the worker,
# to enable it to raise a Bugzilla bug against itself, if it considers that it is in a bad state.
class generic_worker::control_bug (
    String $user_homedir,
    String $bugzilla_api_key,
    String $bugzilla_url = 'https://bugzilla.mozilla.org'
) {

    include generic_worker::settings

    $log_file = '/var/log/system.log'

    file {
        '/usr/local/share/generic-worker':
            ensure => directory,
            owner  => $generic_worker::setttings::root_user,
            group  => $generic_worker::setttings::root_group;

        '/usr/local/share/generic-worker/bugzilla-utils.sh':
            ensure  => present,
            content => template('generic_worker/bugzilla-utils.sh.erb'),
            mode    => '0755',
            owner   => $generic_worker::setttings::root_user,
            group   => $generic_worker::setttings::root_group;
    }
}
