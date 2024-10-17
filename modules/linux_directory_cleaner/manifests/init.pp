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

    # Deploy the clean_before_reboot.sh script to the correct directories
    file { '/etc/init.d/clean_before_reboot':
      ensure => file,
      source => 'puppet:///modules/linux_directory_cleaner/clean_before_reboot.sh',
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    # Create symlinks in rc0.d and rc6.d for shutdown and reboot
    file { '/etc/rc0.d/K01clean_before_reboot':
      ensure  => link,
      target  => '/etc/init.d/clean_before_reboot',
      require => File['/etc/init.d/clean_before_reboot'],
    }

    file { '/etc/rc6.d/K01clean_before_reboot':
      ensure  => link,
      target  => '/etc/init.d/clean_before_reboot',
      require => File['/etc/init.d/clean_before_reboot'],
    }
  }
}
