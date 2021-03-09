# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::py3 {

    # py3.6

    package { 'python3':
        ensure   => present,
    }
    package { 'python3-pip':
        ensure   => present,
    }

    file {'/opt/relops_py3/':
        ensure => directory,
        group  => 'root',
        mode   => '0755',
        owner  => 'root',
    }

    # py3.9, from deadsnakes ppa

    $urls = {
        '/opt/relops_py3/libpython3.9-minimal_3.9.2-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-minimal_3.9.2-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py3/libpython3.9-stdlib_3.9.2-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-stdlib_3.9.2-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py3/python3-distutils_3.6.9-1~18.04_all.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/python3-distutils_3.6.9-1~18.04_all.deb' },
        '/opt/relops_py3/python3-lib2to3_3.6.9-1~18.04_all.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/python3-lib2to3_3.6.9-1~18.04_all.deb' },
        '/opt/relops_py3/python3.9-minimal_3.9.2-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-minimal_3.9.2-1%2Bbionic2_amd64.deb' },
    }
    create_resources(file, $urls, {
        owner => 'root',
        group => 'root',
        mode  => '0644',
    })

    exec { '/usr/bin/dpkg -i *.deb':
        path     => '/bin:/usr/bin/:/sbin:/usr/sbin',
        cwd      => '/opt/relops_py3/',
        provider => shell,
        unless   => '/usr/bin/dpkg --list | /bin/grep python3.9',
    }

}
