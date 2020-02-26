# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::python3_zstandard {
    require linux_packages::py3

    # for the first run, this tries to run pip because pip3 didn't exist
    # at the start at the start of the run. ugh. puppet bug in 5.5.1.
    # https://tickets.puppetlabs.com/browse/PUP-7644
    # package { 'python3-zstandard':
    #     ensure   => '0.11.1',
    #     name     => 'zstandard',
    #     provider => pip3,
    #     require  => Class['linux_packages::py3'],
    # }

    exec { 'install python3-zstandard':
      command => "/usr/bin/pip3 install zstandard==0.11.1",
      unless  => "/usr/bin/pip3 list --format=columns | grep zstandard | grep 0.11.1",
    }
}
