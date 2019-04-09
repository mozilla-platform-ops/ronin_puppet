# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

define python2::user_pip_conf (
    String $user,
    String $group,
    Array $user_python_repositories = [ 'https://pypi.pub.build.mozilla.org/pub', ],
) {

    case $::operatingsystem {
        'Darwin':
        {
            file {
                "/Users/${user}/Library/Application Support/pip/":
                    ensure  => 'directory',
                    owner   => $user,
                    group   => $group,
                    mode    => '0755',
                    require => File["/Users/${user}/Library/Application Support"];

                "/Users/${user}/Library/Application Support/pip/pip.conf":
                    ensure  => 'file',
                    content => template('python2/user-pip-conf.erb'),
                    owner   => $user,
                    group   => $group,
                    mode    => '0644';
            }
        }
        default: {
            fail('This OS is not supported for user_pip_conf')
        }
    }
}
