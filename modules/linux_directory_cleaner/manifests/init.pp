class linux_directory_cleaner (
  Boolean $enabled = true,
) {
  # Install the directory_cleaner package using pip3 as cltbld user
  exec { 'install_directory_cleaner_linux':
    command => '/usr/local/bin/pip3 install --prefix /usr/local directory_cleaner==0.2.0',
    unless  => '/usr/local/bin/pip3 show directory_cleaner | grep "Version: 0.2.0"',
    user    => 'cltbld',
  }

  # Create necessary directories if they do not exist
  file { '/opt/directory_cleaner':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  file { '/opt/directory_cleaner/configs':
    ensure  => directory,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    require => File['/opt/directory_cleaner'],
  }

  # Define the content of the file to be created
  $config_content = @("EOF")
        exclusion_patterns = [

               ]
EOF

  # Create the configuration file with the specified content
  file { '/opt/directory_cleaner/configs/config.toml':
    ensure  => file,
    content => $config_content,
    mode    => '0644',
    owner   => 'root',
    group   => 'wheel',
    require => File['/opt/directory_cleaner/configs'],
  }

  # Deploy the clean_before_reboot.sh script
  file { '/usr/local/bin/clean_before_reboot.sh':
    ensure => file,
    source => 'puppet:///modules/linux_directory_cleaner/clean_before_reboot.sh',
    mode   => '0755',
    owner  => 'root',
    group  => 'wheel',
  }

  # Define the systemd service content
  $systemd_service_content = @("EOF")
  [Unit]
  Description=Run cleanup script before shutdown/reboot
  DefaultDependencies=no
  Before=shutdown.target reboot.target halt.target

  [Service]
  Type=oneshot
  ExecStart=/usr/local/bin/clean_before_reboot.sh
  RemainAfterExit=true

  [Install]
  WantedBy=halt.target reboot.target shutdown.target
EOF

  # Create the systemd service file
  file { '/etc/systemd/system/clean_before_reboot.service':
    ensure  => file,
    content => $systemd_service_content,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => File['/usr/local/bin/clean_before_reboot.sh'],
  }

  # Ensure systemd reloads the service files
  exec { 'systemd-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/clean_before_reboot.service'],
  }

  # Enable the service to run on shutdown/reboot
  service { 'clean_before_reboot':
    ensure  => 'running',
    enable  => true,
    require => Exec['systemd-reload'],
  }
}
