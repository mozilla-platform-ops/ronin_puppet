# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker::base {
    # Dependencies

    contain packages::python3_s3
    file { '/tools/python3':
        ensure  => 'link',
        target  => '/usr/local/bin/python3',
        require => Class['packages::python3_s3'],
    }
    file { ['/builds', '/builds/scriptworker', '/builds/scriptworker/certs']:
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

    $cot_product = $::hostname? {
        /^mac-v3-signing\d+/ => "firefox",
        /^tb-mac-v3-signing\d+/ => "thunderbird",
        /^dep-mac-v3-signing\d+/ => "firefox",
        default => fail("No matching hostname"),
    }

    $taskcluster_scope_prefix = $::hostname? {
        /^mac-v3-signing\d+/ => "project:releng:signing:",
        /^tb-mac-v3-signing\d+/ => "project:comm:thunderbird:releng:signing:",
        /^dep-mac-v3-signing\d+/ => "project:releng:signing:",
        default => fail("No matching hostname"),
    }


    file { $tmp_requirements:
        source => 'puppet:///modules/signing_worker/requirements.txt',
    }

    # DeveloperIDCA.cer is only required on dep, but is harmless on prod
    file {
        "/tmp/DeveloperIDCA.cer":
            source => 'puppet:///modules/signing_worker/DeveloperIDCA.cer',
    }
    exec {
        'install-developer-id-root':
            command => "/usr/bin/security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/DeveloperIDCA.cer",
            require => File["/tmp/DeveloperIDCA.cer"],
            unless  => "/usr/bin/security dump-keychain /Library/Keychains/System.keychain | /usr/bin/grep 'Developer ID Certification'",
            # This command returns an error despite actually importing
            # the certificate correctly.
            # For posterity, the error returned is "SecTrustSettingsSetTrustSettings: The authorization was denied since no user interaction was possible.".
            returns => [1];
    }

    # Install certifi's set of CAs to override the system set
    exec {
        'install_python_certs':
            command => "'/Applications/Python 3.7/Install Certificates.command'",
            path => ['/usr/bin', '/usr/sbin', '/bin'],
            unless =>  "test -h /Library/Frameworks/Python.framework/Versions/3.7/etc/openssl/cert.pm"
    }

    # Accept the xcode licence
    exec {
        'xcode_license_agree':
            command => '/usr/bin/xcodebuild -license accept',
    }

    contain packages::virtualenv_python3_s3
    python::virtualenv { 'signingworker' :
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

    file { "${certs_dir}/widevine_prod.crt":
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        content => lookup('signing_keys.widevine_prod_crt'),
    }
    file { "${certs_dir}/nightly_signing.keychain":
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        content => lookup('signing_keys.nightly_signing_keychain'),
    }
    file { "${certs_dir}/release_signing.keychain":
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        content => lookup('signing_keys.release_signing_keychain'),
    }
    file { "${certs_dir}/ed25519_privkey":
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        content => lookup('signing_keys.ed25519_privkey'),
        mode => '0400',
    }


    # scriptworker config
    file { $script_config_file:
        content => template('signing_worker/script_config.yaml.erb'),
    }
    file { $scriptworker_config_file:
        content => template('signing_worker/scriptworker.yaml.erb'),
    }
}
