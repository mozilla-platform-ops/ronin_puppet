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

    # py3.8, from deadsnakes ppa

    file {'/opt/relops_py38/':
        ensure => directory,
        group  => 'root',
        mode   => '0755',
        owner  => 'root',
    }

    $py38_urls = {
        '/opt/relops_py38/libpython3.8-minimal_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/libpython3.8-minimal_3.8.8-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py38/libpython3.8-stdlib_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/libpython3.8-stdlib_3.8.8-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py38/python3.8_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/python3.8_3.8.8-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py38/python3.8-minimal_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/python3.8-minimal_3.8.8-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py38/python3.8-venv_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/python3.8-venv_3.8.8-1%2Bbionic2_amd64.deb' },
    }

    create_resources(file, $py38_urls, {
        owner => 'root',
        group => 'root',
        mode  => '0644',
    })

    exec { 'install py38':
        command  => '/usr/bin/dpkg -i *.deb',
        path     => '/bin:/usr/bin/:/sbin:/usr/sbin',
        cwd      => '/opt/relops_py38/',
        provider => shell,
        unless   => '/usr/bin/dpkg --list | /bin/grep python3.8 && /usr/bin/python3.8 -c "import distutils"',
    }

    # py3.9, from deadsnakes ppa

    file {'/opt/relops_py39/':
        ensure => directory,
        group  => 'root',
        mode   => '0755',
        owner  => 'root',
    }

    $py39_urls = {
        '/opt/relops_py39/libpython3.9-minimal_3.9.2-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-minimal_3.9.2-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py39/libpython3.9-stdlib_3.9.2-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-stdlib_3.9.2-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py39/python3.9-minimal_3.9.2-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-minimal_3.9.2-1%2Bbionic2_amd64.deb' },
        '/opt/relops_py39/python3.9-distutils_3.9.2-1+bionic2_all.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-distutils_3.9.2-1%2Bbionic2_all.deb' },
        '/opt/relops_py39/python3.9-lib2to3_3.9.2-1+bionic2_all.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-lib2to3_3.9.2-1%2Bbionic2_all.deb' },
    }

    create_resources(file, $py39_urls, {
        owner => 'root',
        group => 'root',
        mode  => '0644',
    })

    exec { 'install py39':
        command  => '/usr/bin/dpkg -i *.deb',
        path     => '/bin:/usr/bin/:/sbin:/usr/sbin',
        cwd      => '/opt/relops_py39/',
        provider => shell,
        unless   => '/usr/bin/dpkg --list | /bin/grep python3.9 && /usr/bin/python3.9 -c "import disutils"',
    }

    # remove old /opt/py3

    file {'/opt/relops_py3/':
        ensure => absent,
    }

}
