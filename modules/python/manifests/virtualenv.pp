#
# @summary Creates Python virtualenv.
#
# Modified from https://github.com/voxpupuli/puppet-python by
# sfraser@mozilla.com for isolated Darwin support.
#
# @param ensure
# @param version Python version to use.
# @param requirements Path to pip requirements.txt file
# @param systempkgs Copy system site-packages into virtualenv.
# @param venv_dir  Directory to install virtualenv to
# @param ensure_venv_dir Create $venv_dir
# @param index Base URL of Python package index
# @param owner The owner of the virtualenv being manipulated
# @param group  The group relating to the virtualenv being manipulated
# @param mode  Optionally specify directory mode
# @param proxy Proxy server to use for outbound connections
# @param environment Additional environment variables required to install the packages
# @param path  Specifies the PATH variable
# @param cwd The directory from which to run the "pip install" command
# @param timeout  The maximum time in seconds the "pip install" command should take
# @param pip_args  Arguments to pass to pip during initialization
# @param extra_pip_args Extra arguments to pass to pip after requirements file
#
# @example install a virtual env at /var/www/project1
#  python::virtualenv { '/var/www/project1':
#    ensure       => present,
#    version      => 'system',
#    requirements => '/var/www/project1/requirements.txt',
#    proxy        => 'http://proxy.domain.com:3128',
#    systempkgs   => true,
#    index        => 'http://www.example.com/simple/',
#  }
#
define python::virtualenv (
  String $ensure                     = present,
  String $version                    = 'system',
  String $requirements               = '',
  Boolean $systempkgs                = false,
  String $venv_dir                   = $name,
  Boolean $ensure_venv_dir           = true,
  Boolean $index                     = false,
  String $owner                      = 'root',
  String $group                      = 'root',
  String $mode                       = '0755',
  Variant[String, Undef] $proxy      = undef,
  Array $environment                 = [],
  Array $path                        = [ '/bin', '/usr/bin', '/usr/sbin', '/usr/local/bin' ],
  Variant[String, Undef] $cwd        = undef,
  Integer $timeout                   = 1800,
  String $pip_args                   = '',
  String $extra_pip_args             = '',
  Variant[String, Undef] $virtualenv = undef
) {

  if $ensure == 'present' {
    require packages::virtualenv

    $python = $version ? {
      'system' => 'python',
      'pypy'   => 'pypy',
      default  => "python${version}",
    }

    if $virtualenv == undef {
      $virtualenv_cmd = 'virtualenv'
    } else {
      $virtualenv_cmd = $virtualenv
    }

    $proxy_flag = $proxy ? {
      false    => '',
      default  => "--proxy=${proxy}",
    }

    $proxy_command = $proxy ? {
      false   => '',
      default => "&& export http_proxy=${proxy}",
    }


    $system_pkgs_flag = $systempkgs ? {
        true    => '--system-site-packages',
        false   => '--no-site-packages',
        default => fail('Invalid value for systempkgs. Boolean value is expected')
    }

    $pypi_index = $index ? {
      false   => '',
      default => "-i ${index}",
    }

    if $ensure_venv_dir {
      file { $venv_dir:
        ensure => directory,
        owner  => $owner,
        group  => $group,
        mode   => $mode,
      }
    }

    $pip_cmd   = "${venv_dir}/bin/pip"
    $pip_flags = "${pypi_index} ${proxy_flag} ${pip_args}"

    # Unless activate exists and VIRTUAL_ENV is correct we re-create the virtualenv
    exec { "python_virtualenv_${venv_dir}":
      command     => @("COMMAND"/L),
        true ${proxy_command} && \
        ${virtualenv_cmd} ${system_pkgs_flag} -p ${python} ${venv_dir} && \
        ${pip_cmd} --log ${venv_dir}/pip.log install ${pip_flags} --upgrade pip
        |-COMMAND
      user        => $owner,
      creates     => "${venv_dir}/bin/activate",
      path        => $path,
      cwd         => '/tmp',
      environment => $environment,
      unless      => "grep '^[\\t ]*VIRTUAL_ENV=[\\\\'\\\"]*${venv_dir}[\\\"\\\\'][\\t ]*$' ${venv_dir}/bin/activate",
      require     => File[$venv_dir],
    }

    if $requirements != '' {
      exec { "python_requirements_initial_install_${requirements}_${venv_dir}":
        command     => @("COMMAND"/L),
          ${pip_cmd} --log ${venv_dir}/pip.log install ${pypi_index} \
          ${proxy_flag} -r ${requirements} ${extra_pip_args}
          |-COMMAND
        refreshonly => true,
        timeout     => $timeout,
        user        => $owner,
        subscribe   => Exec["python_virtualenv_${venv_dir}"],
        environment => $environment,
        cwd         => $cwd,
        require     => File[$requirements],
      }
    }
  } elsif $ensure == 'absent' {
    file { $venv_dir:
      ensure  => absent,
      force   => true,
      recurse => true,
      purge   => true,
    }
  }
}
