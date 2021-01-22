# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
define signing_worker (
    String $role,
    String $user,
    String $password,
    String $salt,
    String $iterations,
    String $scriptworker_base,
    String $dmg_prefix,
    String $cot_product,
    Array $supported_behaviors,
    String $widevine_user,
    String $widevine_key,
    String $widevine_filename,
    Hash $worker_config,
    Hash $role_config,
    Hash $poller_config,
    String $worker_type_prefix = '',
    String $worker_id_suffix = '',
    String $group = 'staff',
    Variant[String, Undef] $ed_key_filename = undef,
    Variant[Array, Undef] $notarization_users = undef,
) {
    $virtualenv_dir           = "${scriptworker_base}/virtualenv"
    $certs_dir                = "${scriptworker_base}/certs"
    $requirements             = "${scriptworker_base}/requirements.txt"
    $scriptworker_config_file = "${scriptworker_base}/scriptworker.yaml"
    $script_config_file       = "${scriptworker_base}/script_config.yaml"
    $scriptworker_wrapper     = "${scriptworker_base}/scriptworker_wrapper.sh"

    # Dep workers have a non-deterministic suffix
    $worker_id = "${facts['networking']['hostname']}${worker_id_suffix}"
    $worker_type = "${worker_type_prefix}${worker_config['worker_type']}"
    case $::fqdn {
        /.*\.mdc1\.mozilla\.com/: {
            $worker_group = mdc1
        }
        /.*\.mdc2\.mozilla\.com/: {
            $worker_group = mdc2
        }
        default: {
            $worker_group = unknown
        }
    }

    $ed_key_path = $ed_key_filename? {
      undef => '/dev/null',
      default => "${certs_dir}/${ed_key_filename}",
    }
    $widevine_cert_path = "${certs_dir}/${widevine_filename}"

    signing_worker::system_user { "create_user_${user}":
        user       => $user,
        password   => $password,
        salt       => $salt,
        iterations => $iterations,
    }

    # Also used in script_config.yaml.erb
    $notary_users = $notarization_users? {
        undef => [],
        default => $notarization_users,
    }
    $notary_users.each |String $user| {
        signing_worker::notarization_user { "create_notary_${user}":
            user => $user,
        }
    }

    $required_directories = [
      $scriptworker_base,
      "${scriptworker_base}/certs",
      "${scriptworker_base}/logs",
      "${scriptworker_base}/artifact",
    ]
    file { $required_directories:
      ensure => 'directory',
      owner  =>  $user,
      group  =>  $group,
      mode   => '0750',
    }

    $scriptworker_clone_dir = "${scriptworker_base}/scriptworker"
    $scriptworker_scripts_clone_dir = "${scriptworker_base}/scriptworker-scripts"
    $widevine_clone_dir = "${scriptworker_base}/widevine"
    $tc_scope_prefix = $cot_product ? {
        'firefox' => $worker_config['taskcluster_scope_prefix'],
        'thunderbird' => $worker_config['tb_taskcluster_scope_prefix'],
    }
    $tc_client_id = $cot_product ? {
        'firefox' => $worker_config['taskcluster_client_id'],
        'thunderbird' => $worker_config['tb_taskcluster_client_id'],
    }
    $tc_access_token = $cot_product ? {
        'firefox' => $worker_config['taskcluster_access_token'],
        'thunderbird' => $worker_config['tb_taskcluster_access_token'],
    }

    file { $requirements:
        source => "puppet:///modules/${module_name}/requirements.${role}.txt",
        owner  => $user,
        group  => $group,
    }

    # Setting up the virtualenv happens in 3 stages:
    # 1) Create it
    # 2) Install indirect dependencies (which have their own requirements file)
    # 3) Install direct dependencies
    # We cannot combine these into one requirements file because the indirect
    # dependencies use hash pinning, while the direct ones cannot, because they're
    # installed in editable mode.
    python::virtualenv { "signingworker_${user}" :
        ensure          => present,
        version         => '3',
        venv_dir        => $virtualenv_dir,
        ensure_venv_dir => true,
        owner           => $user,
        group           => $group,
        timeout         => 0,
        # This is not strictly necessary, but if Puppet ever runs
        # from a cwd that the signing worker user can't access,
        # we end up hitting this pip bug:
        # https://github.com/pypa/pip/issues/9445
        cwd             => $scriptworker_base,
        path            => [ '/bin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/Library/Frameworks/Python.framework/Versions/3.8/bin'],
    }
    exec { "install ${scriptworker_base} requirements":
        command     => "${virtualenv_dir}/bin/pip install -r ${requirements}",
        user        => $user,
        group       => $group,
        refreshonly => true,
        # Make sure these are updated when they change
        subscribe   => [File[$requirements], Python::Virtualenv["signingworker_${user}"]],
        require     => [File[$requirements], Python::Virtualenv["signingworker_${user}"]],
    }

    vcsrepo { $scriptworker_clone_dir:
        ensure   => present,
        provider => git,
        source   => 'https://github.com/mozilla-releng/scriptworker',
        revision => $worker_config['scriptworker_revision'],
        user     => $user,
        group    => $group,
        require  => File[$scriptworker_base],
    }
    exec { "install ${scriptworker_base} scriptworker":
        command     => "${virtualenv_dir}/bin/python setup.py install",
        cwd         => $scriptworker_clone_dir,
        user        => $user,
        group       => $group,
        refreshonly => true,
        subscribe   => [Vcsrepo[$scriptworker_clone_dir], Python::Virtualenv["signingworker_${user}"]],
        require     => [Vcsrepo[$scriptworker_clone_dir], Python::Virtualenv["signingworker_${user}"]],
    }

    vcsrepo { $scriptworker_scripts_clone_dir:
        ensure   => present,
        provider => git,
        source   => 'https://github.com/mozilla-releng/scriptworker-scripts',
        revision => $worker_config['scriptworker_scripts_revision'],
        user     => $user,
        group    => $group,
        require  => File[$scriptworker_base],
    }
    exec { "install ${scriptworker_base} mozbuild":
        command     => "${virtualenv_dir}/bin/python setup.py install",
        cwd         => "${scriptworker_scripts_clone_dir}/vendored/mozbuild",
        user        => $user,
        group       => $group,
        refreshonly => true,
        subscribe   => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
        require     => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
    }
    exec { "install ${scriptworker_base} scriptworker_client":
        command     => "${virtualenv_dir}/bin/python setup.py install",
        cwd         => "${scriptworker_scripts_clone_dir}/scriptworker_client",
        user        => $user,
        group       => $group,
        refreshonly => true,
        subscribe   => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
        require     => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
    }
    exec { "install ${scriptworker_base} iscript":
        command     => "${virtualenv_dir}/bin/python setup.py install",
        cwd         => "${scriptworker_scripts_clone_dir}/iscript",
        user        => $user,
        group       => $group,
        refreshonly => true,
        subscribe   => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
        require     => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
    }
    exec { "install ${scriptworker_base} notarization_poller":
        command     => "${virtualenv_dir}/bin/python setup.py install",
        cwd         => "${scriptworker_scripts_clone_dir}/notarization_poller",
        user        => $user,
        group       => $group,
        refreshonly => true,
        subscribe   => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
        require     => [Vcsrepo[$scriptworker_scripts_clone_dir], Python::Virtualenv["signingworker_${user}"]],
    }

    # We only clone this once for three reasons:
    # 1) It is almost never updated
    # 2) We don't support general code deployments through puppet (yet)
    # 3) The clone url contains a github token, which we don't want sitting around on disk
    #
    # In an ideal world we'd still use `vcsrepo` for this, but it breaks after we
    # clean up the token, so we're stuck with this for now.
    exec { "clone widevine ${scriptworker_base}":
        command => "git clone https://${widevine_user}:${widevine_key}@github.com/mozilla-services/widevine ${widevine_clone_dir}",
        user    => $user,
        group   => $group,
        unless  => "test -d ${widevine_clone_dir}",
        path    => ['/bin', '/usr/bin'],
        require => File[$scriptworker_base],
    }
    # This has credentials in it. Clean up.
    ->file { "Remove widevine directory ${scriptworker_base}":
        ensure  => absent,
        path    => "${widevine_clone_dir}/.git",
        recurse => true,
        purge   => true,
        force   => true,
    }
    exec { "install ${scriptworker_base} widevine":
        command     => "${virtualenv_dir}/bin/python setup.py install",
        cwd         => $widevine_clone_dir,
        user        => $user,
        group       => $group,
        refreshonly => true,
        subscribe   => [Exec["clone widevine ${scriptworker_base}"], Python::Virtualenv["signingworker_${user}"]],
        require     => [Exec["clone widevine ${scriptworker_base}"], Python::Virtualenv["signingworker_${user}"]],
    }

    # XXX once we:
    #     - get the virtualenv to re-run pip on requirements.txt change,
    #     - get the scriptworker and poller to restart on config or python
    #       change, and
    #     - get puppet running periodically,
    #     we can upgrade scriptworker and python deps without sshing in.

    # scriptworker config
    file { $script_config_file:
        content => template('signing_worker/script_config.yaml.erb'),
        owner   => $user,
        group   => $group,
    }
    file { $scriptworker_config_file:
        content => template('signing_worker/scriptworker.yaml.erb'),
        owner   => $user,
        group   => $group,
    }

    file { $scriptworker_wrapper:
        content => template('signing_worker/scriptworker_wrapper.sh.erb'),
        mode    => '0700',
        owner   => $user,
        group   => $group,
    }

    $launchd_script = "/Library/LaunchDaemons/org.mozilla.scriptworker.${user}.plist"
    file { $launchd_script:
        content => template('signing_worker/org.mozilla.scriptworker.plist.erb'),
        mode    => '0644',
    }
    # Disabled until full setup is complete.
    # exec { "${user}_launchctl_load":
    #    command   => "/bin/launchctl load ${$launchd_script}",
    #    subscribe => File[$launchd_script],
    # }

    # Remove this notify when enabling the exec launchctl, above
    notify { "launchctl_${user}":
        message   => "Run: /bin/launchctl load ${$launchd_script}",
        subscribe => File[$launchd_script],
    }

    if !empty($poller_config) {
        signing_worker::notarization_user { "create_user_${poller_config['user']}":
            user => $poller_config['user'],
        }
        $poller_worker_id    = "poller-${facts['networking']['hostname']}"
        $poller_dir          = "${scriptworker_base}/poller"
        $poller_config_file  = "${scriptworker_base}/poller/poller.yaml"
        $poller_wrapper      = "${scriptworker_base}/poller/poller_wrapper.sh"

        $poller_required_directories = [
          $poller_dir,
          "${poller_dir}/logs",
        ]
        file { $poller_required_directories:
          ensure => 'directory',
          owner  =>  $poller_config['user'],
          group  =>  $group,
          mode   => '0750',
        }

        file { $poller_config_file:
            content => template('signing_worker/poller.yaml.erb'),
            owner   => $poller_config['user'],
            group   => $group,
        }

        file { $poller_wrapper:
            content => template('signing_worker/poller_wrapper.sh.erb'),
            mode    => '0700',
            owner   => $poller_config['user'],
            group   => $group,
        }

        $poller_launchd_script = "/Library/LaunchDaemons/org.mozilla.notarization_poller.${poller_config['user']}.plist"
        file { $poller_launchd_script:
            content => template('signing_worker/org.mozilla.notarization_poller.plist.erb'),
            mode    => '0644',
        }
        # Disabled until full setup is complete.
        # exec { "${poller_config['user']}_launchctl_load":
        #    command   => "/bin/launchctl load ${$poller_launchd_script}",
        #    subscribe => File[$poller_launchd_script],
        # }

        # Remove this notify when enabling the exec launchctl, above
        notify { "launchctl_${poller_config['user']}":
            message   => "Run: /bin/launchctl load ${$poller_launchd_script}",
            subscribe => File[$poller_launchd_script],
        }
    }
}
