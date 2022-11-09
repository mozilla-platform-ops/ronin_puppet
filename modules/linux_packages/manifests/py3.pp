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

        # py3.8 is deprecated with 3.6 and 3.9 present
          # py3.8, from deadsnakes ppa
        #   file { '/opt/relops_py38/':
        #     ensure => directory,
        #     group  => 'root',
        #     mode   => '0755',
        #     owner  => 'root',
        #   }

        #   $py38_urls = {
        #     '/opt/relops_py38/libpython3.8-minimal_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/libpython3.8-minimal_3.8.8-1%2Bbionic2_amd64.deb' },
        #     '/opt/relops_py38/libpython3.8-stdlib_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/libpython3.8-stdlib_3.8.8-1%2Bbionic2_amd64.deb' },
        #     '/opt/relops_py38/python3.8_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/python3.8_3.8.8-1%2Bbionic2_amd64.deb' },
        #     '/opt/relops_py38/python3.8-minimal_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/python3.8-minimal_3.8.8-1%2Bbionic2_amd64.deb' },
        #     '/opt/relops_py38/python3.8-venv_3.8.8-1+bionic2_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/linux/public/common/py38/1804/python3.8-venv_3.8.8-1%2Bbionic2_amd64.deb' },
        #   }

        #   create_resources(file, $py38_urls, {
        #       owner => 'root',
        #       group => 'root',
        #       mode  => '0644',
        #   })

        #   exec { 'install py38':
        #     command  => '/usr/bin/dpkg -i *.deb',
        #     path     => '/bin:/usr/bin/:/sbin:/usr/sbin',
        #     cwd      => '/opt/relops_py38/',
        #     provider => shell,
        #     unless   => '/usr/bin/dpkg --list | /bin/grep python3.8 && /usr/bin/python3.8 -c "import distutils"',
        #   }

          # py3.9, from deadsnakes ppa

          file { '/opt/relops_py39/':
            ensure => directory,
            group  => 'root',
            mode   => '0755',
            owner  => 'root',
          }

          $py39_urls = {
            # base
            '/opt/relops_py39/python3.9_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py39/libpython3.9_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py39/libpython3.9-stdlib_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-stdlib_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py39/python3.9-minimal_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-minimal_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py39/libpython3.9-minimal_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-minimal_3.9.15-1%2Bbionic1_amd64.deb' },
            # optional
            '/opt/relops_py39/python3.9-distutils_3.9.15-1+bionic1_all.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-distutils_3.9.15-1%2Bbionic1_all.deb' },
            '/opt/relops_py39/python3.9-lib2to3_3.9.15-1+bionic1_all.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-lib2to3_3.9.15-1%2Bbionic1_all.deb' },
            '/opt/relops_py39/python3.9-venv_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-venv_3.9.15-1%2Bbionic1_amd64.deb' },
            # dev
            '/opt/relops_py39/python3.9-dev_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/python3.9-dev_3.9.15-1%2Bbionic1_amd64.deb' },
            '/opt/relops_py39/libpython3.9-dev_3.9.15-1+bionic1_amd64.deb' => { source => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/py39/1804/libpython3.9-dev_3.9.15-1%2Bbionic1_amd64.deb' },
          }
          # need python3-dev for psutil and zstandard compilation

          create_resources(file, $py39_urls, {
              owner => 'root',
              group => 'root',
              mode  => '0644',
          })

          exec { 'install py39':
            # note the version string
            command  => '/usr/bin/dpkg -i *3.9.15*.deb',
            path     => '/bin:/usr/bin/:/sbin:/usr/sbin',
            cwd      => '/opt/relops_py39/',
            provider => shell,
            # note the version string
            unless   => '/usr/bin/dpkg --list | /bin/grep python3.9 | /bin/grep 3.9.15 && /usr/bin/python3.9 -c "import distutils"',
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

          # pip alternatives (for some reason this is pointing to py3)
          #
          # this does: `Debug: Executing: '/usr/bin/update-alternatives --install /usr/bin/pip pip /usr/bin/pip2 20'`
          alternative_entry { '/usr/bin/pip2':
            ensure   => present,
            altlink  => '/usr/bin/pip',
            altname  => 'pip',
            priority => 20,
            require  => Exec['install py39'],
          }

          # - /usr/bin/pip -> /usr/bin/pip2 (from system, vs pip3)
          alternative_entry { '/usr/bin/pip':
            ensure   => present,
            altlink  => '/usr/bin/pip2',
            altname  => 'pip',
            priority => 20,
            require  => Exec['install py39'],
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

          # remove old /opt/py3
          file { '/opt/relops_py3/':
            ensure => absent,
            force  => true,
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
