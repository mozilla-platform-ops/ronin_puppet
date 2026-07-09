# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class ronin_sbom (
  Boolean $enabled                 = true,
  Boolean $run_on_every_puppet_run = true,
  String[1] $output_basename       = 'ronin-sbom',
  Integer[1] $timeout              = 900,
) {
  if $enabled {
    case $facts['os']['name'] {
      'Windows': {
        $programfiles = $facts['custom_win_programfiles'] ? {
          undef   => 'C:\Program Files',
          default => $facts['custom_win_programfiles'],
        }
        $ruby_exe    = "${programfiles}\\Puppet Labs\\Puppet\\puppet\\bin\\ruby.exe"
        $output_dir  = 'C:\sbom'
        $script_path = "${output_dir}\\generate_ronin_sbom.rb"
        $command     = "& '${ruby_exe}' '${script_path}' --output-directory '${output_dir}' --base-name '${output_basename}'"
        $unless      = "Test-Path '${output_dir}\\${output_basename}.cdx.json'"

        file { $output_dir:
          ensure => directory,
        }

        file { $script_path:
          ensure  => file,
          source  => 'puppet:///modules/ronin_sbom/generate_ronin_sbom.rb',
          require => File[$output_dir],
        }

        if $run_on_every_puppet_run {
          exec { 'generate_ronin_sbom_windows':
            command   => $command,
            provider  => powershell,
            require   => [File[$script_path], File[$output_dir]],
            timeout   => $timeout,
            logoutput => true,
          }
        } else {
          exec { 'generate_ronin_sbom_windows':
            command   => $command,
            provider  => powershell,
            require   => [File[$script_path], File[$output_dir]],
            timeout   => $timeout,
            logoutput => true,
            unless    => $unless,
          }
        }
      }
      'Darwin': {
        $ruby_exe    = '/opt/puppetlabs/puppet/bin/ruby'
        $script_path = '/usr/local/bin/generate_ronin_sbom.rb'
        $output_dir  = '/var/sbom'
        $command     = "${ruby_exe} ${script_path} --output-directory ${output_dir} --base-name ${output_basename}"
        $unless      = "test -s '${output_dir}/${output_basename}.cdx.json'"
        $exec_path   = ['/opt/puppetlabs/puppet/bin', '/opt/puppetlabs/bin',
          '/usr/local/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin']

        file { $script_path:
          ensure => file,
          owner  => 'root',
          group  => 'wheel',
          mode   => '0755',
          source => 'puppet:///modules/ronin_sbom/generate_ronin_sbom.rb',
        }

        file { $output_dir:
          ensure => directory,
          owner  => 'root',
          group  => 'wheel',
          mode   => '0755',
        }

        if $run_on_every_puppet_run {
          exec { 'generate_ronin_sbom_darwin':
            command   => $command,
            path      => $exec_path,
            require   => [File[$script_path], File[$output_dir]],
            timeout   => $timeout,
            logoutput => true,
          }
        } else {
          exec { 'generate_ronin_sbom_darwin':
            command   => $command,
            path      => $exec_path,
            require   => [File[$script_path], File[$output_dir]],
            timeout   => $timeout,
            logoutput => true,
            unless    => $unless,
          }
        }
      }
      default: {
        if $facts['kernel'] == 'Linux' {
          $ruby_exe    = '/opt/puppetlabs/puppet/bin/ruby'
          $script_path = '/usr/local/bin/generate_ronin_sbom.rb'
          $output_dir  = '/var/sbom'
          $command     = "${ruby_exe} ${script_path} --output-directory ${output_dir} --base-name ${output_basename}"
          $unless      = "test -s '${output_dir}/${output_basename}.cdx.json'"
          $exec_path   = ['/opt/puppetlabs/puppet/bin', '/opt/puppetlabs/bin',
            '/usr/local/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin']

          file { $script_path:
            ensure => file,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
            source => 'puppet:///modules/ronin_sbom/generate_ronin_sbom.rb',
          }

          file { $output_dir:
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
          }

          if $run_on_every_puppet_run {
            exec { 'generate_ronin_sbom_linux':
              command   => $command,
              path      => $exec_path,
              require   => [File[$script_path], File[$output_dir]],
              timeout   => $timeout,
              logoutput => true,
            }
          } else {
            exec { 'generate_ronin_sbom_linux':
              command   => $command,
              path      => $exec_path,
              require   => [File[$script_path], File[$output_dir]],
              timeout   => $timeout,
              logoutput => true,
              unless    => $unless,
            }
          }
        } else {
          fail("${facts['os']['name']} not supported")
        }
      }
    }
  }
}
