class macos_directory_cleaner (
  Boolean $enabled = true,
) {
  # Install the directory_cleaner package using pip3
  exec { 'install_directory_cleaner':
    command => '/Library/Frameworks/Python.framework/Versions/3.11/bin/pip3 install directory_cleaner',
    # require => Package['python3-pip'],
    unless  => '/Library/Frameworks/Python.framework/Versions/3.11/bin/pip3 show directory_cleaner',
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
}
