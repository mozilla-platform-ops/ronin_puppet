# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
define signing_worker (
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
    String $worker_id_suffix = '',
    String $group = 'staff',
    String $ed_key_filename = undef,
    Array $notarization_users = undef,
) {
    $virtualenv_dir           = "${scriptworker_base}/virtualenv"
    $certs_dir                = "${scriptworker_base}/certs"
    $tmp_requirements         = "${scriptworker_base}/requirements.txt"
    $scriptworker_config_file = "${scriptworker_base}/scriptworker.yaml"
    $script_config_file       = "${scriptworker_base}/script_config.yaml"
    $scriptworker_wrapper     = "${scriptworker_base}/scriptworker_wrapper.sh"

    # Dep workers have a non-deterministic suffix
    $worker_id = "${facts['networking']['hostname']}${worker_id_suffix}"


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

    $widevine_clone_dir = "${scriptworker_base}/widevine"
    file { $tmp_requirements:
        content => template('signing_worker/requirements.txt.erb'),
        owner   =>  $user,
        group   =>  $group,
    }

    exec { 'widevine_check':
        command => '/usr/bin/true',
        unless  => "test -d ${widevine_clone_dir}",
        path    => ['/bin', '/usr/bin'],
    }
    ->vcsrepo { $widevine_clone_dir:
      ensure   => present,
      provider => git,
      source   => "https://${widevine_user}:${widevine_key}@github.com/mozilla-services/widevine",
    }
    # This has credentials in it. Clean up.
    ->file { 'Remove widevine directory':
        ensure  => absent,
        path    => "${widevine_clone_dir}/.git",
        recurse => true,
        purge   => true,
        force   => true,
    }

    contain packages::virtualenv_python3_s3
    python::virtualenv { "signingworker_${user}" :
        ensure          => present,
        version         => '3',
        requirements    => $tmp_requirements,
        venv_dir        => $virtualenv_dir,
        ensure_venv_dir => true,
        owner           => $user,
        group           => $group,
        timeout         => 0,
        path            => [ '/bin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/Library/Frameworks/Python.framework/Versions/3.7/bin'],
    }

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
}
