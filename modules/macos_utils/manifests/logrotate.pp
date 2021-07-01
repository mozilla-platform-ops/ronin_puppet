# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::logrotate (
    String $path,
    String $owner                     = 'root',
    String $mode                      = '666', # File mode of log file
    String $count                     = '2',   # How many files to retain
    String $size                      = '*',   # How big until rotation (Size in KB)
    String $when                      = '$D0', # When to rotate (eg. every 24h)
    String $flags                     = 'J',   # Flags (eg. J == bzip compression)
    String $pid_file                  = '',
    Enum['present', 'absent'] $ensure = 'present',
) {

    case $::operatingsystem {
        'Darwin': {
            file { "/etc/newsyslog.d/${title}.conf":
                ensure  => $ensure,
                content => template('macos_utils/newsyslog.conf.erb');
            }
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }

}
