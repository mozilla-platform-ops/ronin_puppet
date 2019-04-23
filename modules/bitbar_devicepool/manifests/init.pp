class bitbar_devicepool {
    
  include ::bitbar_devicepool::systemd_reload

  # install fcgiwrap
  package { 'fcgiwrap':
    ensure => installed,
  }

  vcsrepo { '/home/bitbar/mozilla-bitbar-devicepool':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/bclary/mozilla-bitbar-devicepool.git',
    # user     => 'blake',
  }

  # service { "getty@ttyUSB0.service":
  #   provider => systemd,
  #   ensure => running,
  #   enable => true,
  # }

  file { '/etc/systemd/system/bitbar.service':
    source => '/home/bitbar/mozilla-bitbar-devicepool/service/bitbar.service',
    ensure => file,
    notify => [
      Class['bitbar_devicepool::systemd_reload'],
      Service['fcgiwrap'],
    ],
  }

  service { 'fcgiwrap':
    provider => systemd,
    ensure => running,
    enable => true,
    require => Class['bitbar_devicepool::systemd_reload'],
  }
}
