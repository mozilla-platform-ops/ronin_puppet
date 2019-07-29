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

    $virtualenv_dir = "${scriptworker_base}/virtualenv",
    $tmp_requirements = "${scriptworker_base}/requirements.txt",
    $scriptworker_config_file = "${scriptworker_base}/scriptworker.yaml",
    $script_config_file = "${scriptworker_base}/script_config.yaml",

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

    file { '/builds/scriptworker':
      ensure => 'directory',
      owner  =>  $signing_worker::user,
      group  =>  $signing_worker::group,
      mode   => '0750',
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
    # scriptworker config
    file { $script_config_file:
        content => template('signing_worker/script_config.yaml.erb'),
    }
}
