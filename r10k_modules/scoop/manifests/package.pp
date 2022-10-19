# @summary Install or uninstall a Scoop package
#
# @example Install a package
#   scoop::package { 'firefox':
#     ensure => 'present',
#   }
#
# @example Uninstall a package
#   scoop::package { 'firefox':
#     ensure => 'absent',
#   }
#
# @param ensure
#   Specifies whether to create the bucket. Valid values are 'present', 'absent'. Defaults to 'present'.
#
define scoop::package (
  Enum['present', 'absent'] $ensure = 'present',
) {
  include ::scoop::install

  $is_installed = has_key($facts['scoop']['packages'], $name)
  $install_failed = $is_installed ? {
    true    => $facts['scoop']['packages'][$name]['bucket'] == '',
    default => false,
  }

  case $ensure {
    'absent': {
      if $is_installed {
        exec { "uninstall ${name}":
          command     => "${scoop::set_path}; ${scoop::scoop_exec} uninstall '${name}' --global",
          environment => [
            "SCOOP=${scoop::basedir}",
          ],
          provider    => 'powershell',
        }
      }
    }
    default: {
      if $install_failed {
        exec { "uninstall ${name}":
          command     => "${scoop::set_path}; ${scoop::scoop_exec} uninstall '${name}' --global",
          environment => [
            "SCOOP=${scoop::basedir}",
          ],
          provider    => 'powershell',
          logoutput   => true,
          before      => Exec["install ${name}"],
        }
      }

      if $install_failed or !$is_installed {
        exec { "install ${name}":
          command     => "${scoop::set_path}; ${scoop::scoop_exec} install '${name}' --global",
          environment => [
            "SCOOP=${scoop::basedir}",
          ],
          provider    => 'powershell',
          logoutput   => true,
        }
      }
    }
  }
}
