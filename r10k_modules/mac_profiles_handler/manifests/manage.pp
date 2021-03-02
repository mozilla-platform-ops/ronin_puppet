# manage mac profiles
define mac_profiles_handler::manage(
  $file_source = '',
  $ensure = 'present',
  $type = 'mobileconfig',
) {

  if $facts['os']['name'] != 'Darwin' {
    fail('The mobileconfig::manage resource type is only supported on macOS')
  }

  case $ensure {
    'absent': {
      profile_manager { $name:
        ensure    => $ensure,
      }
    }
    default: {
      File {
        owner  => 'root',
        group  => 'wheel',
        mode   => '0700',
      }

      if ! defined(File["/var/db/mobileconfigs"]) {
        file { "/var/db/mobileconfigs":
          ensure => directory,
        }
      }
      case $type {
        'template': {
          file { "/var/db/mobileconfigs/${name}":
            ensure  => file,
            content => $file_source,
          }
        }
        default: {
          file { "/var/db/mobileconfigs/${name}":
            ensure => file,
            source => $file_source,
          }
        }
      }
      profile_manager { $name:
        ensure    => $ensure,
        profile   => "/var/db/mobileconfigs/${name}",
        require   => File["/var/db/mobileconfigs/${name}"],
        subscribe => File["/var/db/mobileconfigs/${name}"],
      }
    }
  }

}

