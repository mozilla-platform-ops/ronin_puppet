# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class python2::system_pip_conf {

    $user_python_repositories = [ 'https://pypi.pub.build.mozilla.org/pub', ]

    case $::operatingsystem {
        'Darwin':
        {
            file {
                '/Library/Application Support/pip/':
                    ensure => 'directory',
                    owner  => 'root',
                    group  => 'wheel',
                    mode   => '0644';

                '/Library/Application Support/pip/pip.conf':
                    ensure  => 'file',
                    content => template('python2/user-pip-conf.erb'),
                    owner   => 'root',
                    group   => 'wheel',
                    mode    => '0644';
            }
        }
        default: {
            fail('This OS is not supported for system_pip_conf')
        }
    }
}
