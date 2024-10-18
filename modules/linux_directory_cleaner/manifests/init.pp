class linux_directory_cleaner (
  Boolean $enabled = true,
) {
  if $enabled {
    # Install the directory_cleaner package using pip3
    package { 'python3-directory_cleaner':
      ensure   => '0.2.0',
      name     => 'directory_cleaner',
      provider => pip3,
      require  => Class['linux_packages::py3', 'linux_python'],
    }

    # Create necessary directories
    file { '/opt/directory_cleaner':
      ensure => directory,
      owner  => 'root',
      group  => 'admin',
      mode   => '0755',
    }

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
      # ensure  => 'running',
      enable  => true,
      require => Exec['systemd-reload'],
    }
  }
}
