class linux_directory_cleaner (
  Boolean $enabled = true,
) {
  if $enabled {
    # create the directory_cleaner directory
    file { '/opt/directory_cleaner':
      ensure => directory,
      owner  => 'root',
      group  => 'admin',
      mode   => '0755',
    }

    # block checking for ubuntu, then ubuntu 18.04, 20.04, 22.04. 24.04 should be a separate case.
    case $facts['os']['name'] {
      'Ubuntu': {
        case $facts['os']['release']['full'] {
          '24.04': {
            # install into a venv

            # if /opt/directory_cleaner/venv doesn't exist, create it
            exec { 'create_directory_cleaner_venv':
              command => '/usr/bin/python3 -m venv /opt/directory_cleaner/venv',
              creates => '/opt/directory_cleaner/venv',
              require => [File['/opt/directory_cleaner'],
                Class['linux_packages::py3'],
              Class['linux_python']],
            }

            # install the directory_cleaner package into the venv
            exec { 'install_directory_cleaner':
              command => '/opt/directory_cleaner/venv/bin/pip install directory_cleaner',
              path    => ['/usr/bin', '/bin', '/opt/directory_cleaner/venv/bin'],
              creates => '/opt/directory_cleaner/venv/lib/python3.10/site-packages/directory_cleaner',
              require => Exec['create_directory_cleaner_venv'],
            }

            # create a symlink to /usr/local/bin/directory_cleaner
            file { '/usr/local/bin/directory_cleaner':
              ensure  => link,
              target  => '/opt/directory_cleaner/venv/bin/directory_cleaner',
              require => Exec['install_directory_cleaner'],
            }
          }
          '18.04', '22.04': {
            # install into the system Python3 environment

            package { 'python3-directory_cleaner':
              ensure   => '0.2.0',
              name     => 'directory_cleaner',
              provider => pip3,
              require  => Class['linux_packages::py3', 'linux_python'],
            }
          }
          default: {
            fail("Unsupported Ubuntu version: ${facts['os']['release']['full']}")
          }
        }
      }
      default: {
        fail("Cannot install directory_cleaner on ${facts['os']['name']}")
      }
    }

    # Create necessary directories

    file { '/opt/directory_cleaner/configs':
      ensure  => directory,
      owner   => 'root',
      group   => 'admin',
      mode    => '0755',
      require => File['/opt/directory_cleaner'],
    }

    # Define the content of the file to be created
    $config_content = @("EOF")
        exclusion_patterns = []
EOF

    # Create the configuration file
    file { '/opt/directory_cleaner/configs/config.toml':
      ensure  => file,
      content => $config_content,
      mode    => '0644',
      owner   => 'root',
      group   => 'admin',
      require => File['/opt/directory_cleaner/configs'],
    }

    # Deploy the clean_at_startup.sh script
    file { '/usr/local/bin/clean_at_startup.sh':
      ensure => file,
      source => 'puppet:///modules/linux_directory_cleaner/clean_at_startup.sh',
      mode   => '0755',
      owner  => 'root',
      group  => 'admin',
    }

    # Define the systemd service content
    $systemd_service_content = @("EOF")
      [Unit]
Description=Clean directory at startup
Before=run-puppet.service

[Service]
ExecStart=/usr/local/bin/clean_at_startup.sh

[Install]
WantedBy=multi-user.target
EOF

    # Create the systemd service file
    file { '/etc/systemd/system/clean_at_startup.service':
      ensure  => file,
      content => $systemd_service_content,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => File['/usr/local/bin/clean_at_startup.sh'],
    }

    # Ensure systemd reloads the service files
    exec { 'systemd-reload':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      subscribe   => File['/etc/systemd/system/clean_at_startup.service'],
    }

    # Enable the service to run at startup
    service { 'clean_at_startup':
      # don't ensure running, we want it to run once at startup
      # ensure  => 'running',
      enable  => true,
      require => Exec['systemd-reload'],
    }
  }
}
