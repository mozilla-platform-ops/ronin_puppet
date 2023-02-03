# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class dirs::tools {

    case $::operatingsystem {
        'Darwin': {
            case $facts['os']['macosx']['version']['major'] {
                '11': {
                    file { '/etc/synthetic.conf':
                        ensure => file,
                    }
                    file_line { 'link into root':
                        path => '/etc/synthetic.conf',
                        line => 'tools	System/Volumes/Data/tools',  # must be tab-separated
                    }

                    file { '/System/Volumes/Data/tools':
                        ensure => directory,
                        mode   => '0755',
                    }

                    file { '/System/Volumes/Data/tools/bin':
                        ensure => directory,
                        mode   => '0755',
                    }
                }
                default: {
                    file { '/tools':
                        ensure => directory,
                        mode   => '0755',
                    }
                }
            }
        }
        default: {
            file { '/tools':
                ensure => directory,
                mode   => '0755',
            }
        }
    }
}
