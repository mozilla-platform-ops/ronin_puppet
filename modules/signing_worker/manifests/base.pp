# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker::base {
    # Dependencies

    contain packages::python3
    file { '/tools/python3':
        ensure  => 'link',
        target  => '/usr/local/bin/python3',
        require => Class['packages::python3'],
    }

    file { $signing_worker::tmp_requirements:
        source => 'puppet:///modules/signing_worker/requirements.txt',
    }

    # DeveloperIDCA.cer is only required on dep, but is harmless on prod
    file {
        "${root}/DeveloperIDCA.cer":
            source => 'puppet:///modules/signing_worker/DeveloperIDCA.cer',
    }
    exec {
        'install-developer-id-root':
            command => "/usr/bin/security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain ${root}/DeveloperIDCA.cer",
            require => File["${root}/DeveloperIDCA.cer"],
            unless  => "/usr/bin/security dump-keychain /Library/Keychains/System.keychain | /usr/bin/grep 'Developer ID Certification'",
            # This command returns an error despite actually importing
            # the certificate correctly.
            # For posterity, the error returned is "SecTrustSettingsSetTrustSettings: The authorization was denied since no user interaction was possible.".
            returns => [1];
    }

    # Install certifi's set of CAs to override the system set
    exec {
        'install_python_certs':
            command => '/Applications/Python\ 3.7/Install\ Certificates.command',
            unless =>  "test -h /Library/Frameworks/Python.framework/Versions/3.7/etc/openssl/cert.pm"
    }

    # Accept the xcode licence
    exec {
        'xcode_license_agree':
            command => '/usr/bin/xcodebuild -license accept',
    }

    contain packages::virtualenv
    python::virtualenv { 'signingworker' :
        ensure          => present,
        version         => '3',
        requirements    => $signing_worker::tmp_requirements,
        venv_dir        => $signing_worker::virtualenv_dir,
        ensure_venv_dir => true,
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        timeout         => 0,
    }
    # scriptworker config
    file { $signing_worker::script_config_file:
        content => template('signing_worker/script_config.yaml.erb'),
    }

    # Start service
    supervisord::supervise {
      'signingworker':
          command      => "${signing_worker::virtualenv_dir}/bin/iscript ${signing_worker::script_config_file}",
          user         => $signing_worker::user,
          extra_config => template('signing_worker/supervisor_config.erb');
  }

}
