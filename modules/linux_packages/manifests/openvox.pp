class linux_packages::openvox {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04':  {
          fail('not implemented yet')
        }
        '24.04': {
          # Purge puppet packages first
          $packages_to_purge = [
            'puppet-agent',
            'puppet-release',
            'puppet5-release',
            'puppet6-release',
            'puppet7-release',
            'puppet8-release',
          ]

          package { $packages_to_purge:
            ensure => purged,
          }

          # install openvox
          #
          # wget https://apt.voxpupuli.org/openvox8-release-ubuntu24.04.deb
          # dpkg -i openvox8-release-ubuntu24.04.deb
          # apt update
          # apt install openvox-agent
          # fetch and install the openvox repo deb
          $deb_name = 'openvox8-release-ubuntu24.04.deb'
          # file { 'openvox_repo_deb':
          #   ensure => 'file',
          #   path   => "/tmp/${deb_name}",
          #   mode   => 'a+r',
          #   source => "https://apt.voxpupuli.org/${deb_name}",
          # }
          # use an exec and wget instead
          exec { 'get_openvox_release_deb_file':
            command => "/usr/bin/wget -O /tmp/${deb_name} https://apt.voxpupuli.org/${deb_name}",
            creates => '/etc/apt/sources.list.d/openvox8-release.list',
            require => Package[$packages_to_purge],
          }
          exec { 'install_openvox_release_deb':
            command     => "/usr/bin/dpkg -i /tmp/${deb_name}",
            creates     => '/etc/apt/sources.list.d/openvox8-release.list',
            # only run this if the exec above runs (which only runs if the 'creates' file is missing)
            subscribe   => Exec['get_openvox_release_deb_file'],
            refreshonly => true,
          }

          # install openvox-agent
          package { 'install openvox agent':
            ensure    => installed,
            name      => 'openvox-agent',
            require   => Exec['apt_update'],
            subscribe => Exec['install_openvox_release_deb'],
          }
        }
        default: {
          fail("linux_packages::openvox not supported on Ubuntu ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("linux_packages::openvox not supported on ${facts['os']['name']}")
    }
  }
}
