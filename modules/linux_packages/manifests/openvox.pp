class linux_packages::openvox {
  case $facts['os']['name'] {
    'Ubuntu': {
      $supported_versions = ['18.04', '22.04', '24.04']
      unless $facts['os']['release']['full'] in $supported_versions {
        fail("linux_packages::openvox not supported on Ubuntu ${facts['os']['release']['full']}")
      }

      include apt

      # test-kitchen / CI testing:
      #   Disable the puppet service left behind by the omnibus installer
      service { 'puppet':
        ensure => stopped,
        enable => false,
      }

      # Purge puppet packages first
      # don't remove 'puppet-agent', openvox-agent defines it as a conflict and removes it
      # - removing explicitly here breaks puppet. has to be done atomically by apt.
      $packages_to_purge = [
        'puppet-release',
        'puppet5-release',
        'puppet6-release',
        'puppet7-release',
        'puppet8-release',
      ]

      package { $packages_to_purge:
        ensure => purged,
      }

      # fetch and install the openvox repo deb
      $deb_name = "openvox8-release-ubuntu${facts['os']['release']['full']}.deb"
      exec { 'get_openvox_release_deb_file':
        command => "/usr/bin/wget -O /tmp/${deb_name} https://apt.voxpupuli.org/${deb_name}",
        creates => '/etc/apt/sources.list.d/openvox8-release.list',
        require => Package[$packages_to_purge],
      }
      exec { 'install_openvox_release_deb':
        command     => "/usr/bin/dpkg -i /tmp/${deb_name}",
        creates     => '/etc/apt/sources.list.d/openvox8-release.list',
        subscribe   => Exec['get_openvox_release_deb_file'],
        notify      => Exec['apt_update'],
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
      fail("linux_packages::openvox not supported on ${facts['os']['name']}")
    }
  }
}
