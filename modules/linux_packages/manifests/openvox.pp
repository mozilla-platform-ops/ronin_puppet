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
          file { 'openvox_repo_deb':
            ensure => 'file',
            path   => "/tmp/${deb_name}",
            mode   => 'a+r',
            source => "https://apt.voxpupuli.org/${deb_name}",
            unless => 'dpkg -l | grep -q "^ii.*openvox8-release"',
          }
          package { 'openvox repo deb':
            ensure    => installed,
            provider  => dpkg,
            source    => "/tmp/${deb_name}",
            notify    => Exec['apt_update'],
            subscribe => File['openvox_repo_deb'],
            unless    => 'dpkg -l | grep -q "^ii.*openvox8-release"',
          }

          # install openvox-agent
          package { 'install openvox agent':
            ensure    => installed,
            name      => 'openvox-agent',
            require   => Exec['apt_update'],
            subscribe => Package['openvox repo deb'],
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
