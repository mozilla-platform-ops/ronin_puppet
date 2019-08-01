# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker::base {

    $required_directories = [
      $signing_worker::scriptworker_base,
      "${signing_worker::scriptworker_base}/certs",
      "${signing_worker::scriptworker_base}/logs",
      "${signing_worker::scriptworker_base}/artifact",
    ]
    file { $required_directories:
      ensure => 'directory',
      owner  =>  $signing_worker::user,
      group  =>  $signing_worker::group,
      mode   => '0750',
    }

    $virtualenv_dir = "${signing_worker::scriptworker_base}/virtualenv"
    $certs_dir = "${signing_worker::scriptworker_base}/certs"
    $tmp_requirements = "${signing_worker::scriptworker_base}/requirements.txt"
    $scriptworker_config_file = "${signing_worker::scriptworker_base}/scriptworker.yaml"
    $script_config_file = "${signing_worker::scriptworker_base}/script_config.yaml"
    $scriptworker_wrapper = "${signing_worker::scriptworker_base}/scriptworker_wrapper.sh"

    # Dep workers have a non-deterministic suffix
    $worker_id = "${::hostname}${signing_worker::worker_id_suffix}"

    $role = $::hostname? {
        /^mac-v3-signing\d+/ => 'ff-prod',
        /^tb-mac-v3-signing\d+/ => 'tb-prod',
        /^dep-mac-v3-signing\d+/ => 'dep',
        default => fail('No matching hostname'),
    }

    # Load hash of all the template variables
    $role_config = lookup("signingworker.${role}", Hash, undef, undef)

    file { $tmp_requirements:
        source => 'puppet:///modules/signing_worker/requirements.txt',
    }


    contain packages::virtualenv_python3_s3
    python::virtualenv { "signingworker_${signing_worker::user}" :
        ensure          => present,
        version         => '3',
        requirements    => $tmp_requirements,
        venv_dir        => $virtualenv_dir,
        ensure_venv_dir => true,
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        timeout         => 0,
        path            => [ '/bin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/Library/Frameworks/Python.framework/Versions/3.7/bin'],
    }


    case $::hostname {
        /^dep-mac-v3-signing\d+/: {
            file { "${certs_dir}/widevine_dep.crt":
                owner   => $signing_worker::user,
                group   => $signing_worker::group,
                content => base64('decode', lookup('signing_keys.widevine_dep_crt')),
            }
            file { "${certs_dir}/dep-signing.keychain":
                owner   => $signing_worker::user,
                group   => $signing_worker::group,
                content => base64('decode', lookup('signing_keys.dep_signing_keychain')),
            }
        }
        default: {
            file { "${certs_dir}/widevine_prod.crt":
                owner   => $signing_worker::user,
                group   => $signing_worker::group,
                content => base64('decode', lookup('signing_keys.widevine_prod_crt')),
            }
            file { "${certs_dir}/nightly_signing.keychain":
                owner   => $signing_worker::user,
                group   => $signing_worker::group,
                content => base64('decode', lookup('signing_keys.nightly_signing_keychain')),
            }
            file { "${certs_dir}/release_signing.keychain":
                owner   => $signing_worker::user,
                group   => $signing_worker::group,
                content => base64('decode', lookup('signing_keys.release_signing_keychain')),
            }
            file { "${certs_dir}/ed25519_privkey":
                owner   => $signing_worker::user,
                group   => $signing_worker::group,
                content => lookup('signing_keys.ed25519_privkey'),
                mode    => '0400',
            }
        }
    }

    $widevine_cert_path = $::hostname? {
        /^dep-mac-v3-signing\d+/ => "${certs_dir}/widevine_dep.crt",
        default => "${certs_dir}/widevine_prod.crt",
    }
    $ed_key_path = $::hostname? {
        /^dep-mac-v3-signing\d+/ => '/dev/null',
        default => "${certs_dir}/ed25519_privkey",
    }

    # scriptworker config
    file { $script_config_file:
        content => template('signing_worker/script_config.yaml.erb'),
    }
    file { $scriptworker_config_file:
        content => template('signing_worker/scriptworker.yaml.erb'),
    }

    file { $scriptworker_wrapper:
        content => template('signing_worker/scriptworker_wrapper.sh.erb'),
        mode    => '0700',
        owner   => $signing_worker::user,
        group   => $signing_worker::group,
    }

    $launchd_script = "/Library/LaunchDaemons/org.mozilla.scriptworker.${signing_worker::user}.plist"
    file { $launchd_script:
        content => template('signing_worker/org.mozilla.scriptworker.plist.erb'),
        mode    => '0644',
    }
    exec { "${signing_worker::user}_launchctl_load":
        command => "/bin/launchctl load ${$launchd_script}",
        subscribe   => File[$launchd_script],
    }
}
