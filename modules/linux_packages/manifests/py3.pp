# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::py3 {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['major'] {
        '18.04': {
          # py3.6
          package { 'python3':
            ensure   => present,
          }
          package { 'python3-pip':
            ensure   => present,
          }

          # py3.9, from deadsnakes ppa

          file { '/opt/relops_py3915/':
            ensure => directory,
            group  => 'root',
            mode   => '0755',
            owner  => 'root',
          }

          file { '/opt/relops_py3915/py3915_install.sh':
            ensure => present,
            group  => 'root',
            mode   => '0755',
            owner  => 'root',
            source => "puppet:///modules/${module_name}/py3915_install.sh",
          }

          $py39_urls = {
            # base
            '/opt/relops_py3915/python3.9_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py3915/libpython3.9_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py3915/libpython3.9-stdlib_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-stdlib_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py3915/python3.9-minimal_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-minimal_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py3915/libpython3.9-minimal_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-minimal_3.9.15-1%2Bbionic1_amd64.deb' },
            # optional
            '/opt/relops_py3915/python3.9-distutils_3.9.15-1+bionic1_all.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-distutils_3.9.15-1%2Bbionic1_all.deb' },
            '/opt/relops_py3915/python3.9-lib2to3_3.9.15-1+bionic1_all.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-lib2to3_3.9.15-1%2Bbionic1_all.deb' },
            '/opt/relops_py3915/python3.9-venv_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-venv_3.9.15-1%2Bbionic1_amd64.deb' },
            # dev
            '/opt/relops_py3915/python3.9-dev_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-dev_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py3915/libpython3.9-dev_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-dev_3.9.15-1%2Bbionic1_amd64.deb' },
          }
          # need python3-dev for psutil and zstandard compilation

          create_resources(file, $py39_urls, {
              owner => 'root',
              group => 'root',
              mode  => '0644',
          })

          exec { 'install py39':
            command  => '/opt/relops_py3915/py3915_install.sh',
            path     => '/bin:/usr/bin/:/sbin:/usr/sbin',
            cwd      => '/opt/relops_py3915/',
            provider => shell,
            unless   => '/usr/bin/dpkg --list | /bin/grep -v rc | /bin/grep "python3.9 " | /bin/grep "3.9.15" \
              && /usr/bin/python3 -c "import distutils"',
          }

          # configure alternatives
          #
          # system default py3.6 (what's installed by default)
          alternative_entry { '/usr/bin/python3.6':
            ensure   => present,
            altlink  => '/usr/bin/python3',
            altname  => 'python3',
            priority => 10,
          }
          # set py3.9 as a higher level override
          alternative_entry { '/usr/bin/python3.9':
            ensure   => present,
            altlink  => '/usr/bin/python3',
            altname  => 'python3',
            priority => 20,
            require  => Exec['install py39'],
          }

          # /usr/bin/pip ends up pointing at py3 after py3.9 install, fix that.
          #   /usr/bin/pip -> /usr/bin/pip2 (from system, vs pip3)
          alternative_entry { '/usr/bin/pip2':
            ensure   => present,
            altlink  => '/usr/bin/pip',
            altname  => 'pip',
            priority => 20,
            require  => Exec['install py39'],
          }

          # update some pips that prevent other pip installations (psutil) from failing

          package { 'python3-pip-specific-version':
            ensure   => '22.3.1',
            name     => 'pip',
            provider => pip3,
            require  => Alternative_entry['/usr/bin/python3.9'],
          }

          package { 'python3-distlib':
            ensure   => '0.3.6',
            name     => 'distlib',
            provider => pip3,
            require  => Alternative_entry['/usr/bin/python3.9'],
          }

          package { 'python3-setuptools':
            ensure   => '65.5.0',
            name     => 'setuptools',
            provider => pip3,
            require  => Alternative_entry['/usr/bin/python3.9'],
          }

          # pip install above creates /usr/local/bin/pip (that points to py3), and messes with everything, so remove it.
          file { '/usr/local/bin/pip':
              ensure  => absent,
              require => Package['python3-pip-specific-version'],
          }

          # remove old /opt/py3 dirs

          file { '/opt/relops_py3/':
            ensure => absent,
            force  => true,

          }
          file { '/opt/relops_py38/':
            ensure => absent,
            force  => true,
          }
          # TODO: cleanup relops_py39
        }
        '22.04': {
          # ships with py3.10
          package { 'python3':
            ensure   => present,
          }
          package { 'python3-pip':
            ensure   => present,
          }

          # update some pips that prevent other pip installations (psutil) from failing

          package { 'python3-pip-specific-version':
            ensure   => '22.3.1',
            name     => 'pip',
            provider => pip3,
          }

          package { 'python3-distlib':
            ensure   => '0.3.6',
            name     => 'distlib',
            provider => pip3,
          }

          package { 'python3-setuptools':
            ensure   => '65.5.0',
            name     => 'setuptools',
            provider => pip3,
          }
        }
        default: {
          fail("${facts['os']['release']['major']} not supported")
        }
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
