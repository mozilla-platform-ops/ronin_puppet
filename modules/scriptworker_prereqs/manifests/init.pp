# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class scriptworker_prereqs {
    contain packages::python3
    file { '/tools/python3':
            ensure  => 'link',
            target  => '/usr/local/bin/python3',
            require => Class['packages::python3'],
    }

    include dirs::builds

    # DeveloperIDCA.cer is only required on dep, but is harmless on prod
    file {
        '/tmp/DeveloperIDCA.cer':
            source => 'puppet:///modules/scriptworker_prereqs/DeveloperIDCA.cer',
    }
    exec {
        'install-developer-id-root':
            command => '/usr/bin/security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/DeveloperIDCA.cer',
            require => File['/tmp/DeveloperIDCA.cer'],
            unless  => "/usr/bin/security dump-keychain /Library/Keychains/System.keychain | /usr/bin/grep 'Developer ID Certification'",
            # This command returns an error despite actually importing
            # the certificate correctly.
            # For posterity, the error returned is "SecTrustSettingsSetTrustSettings: The authorization was
            # denied since no user interaction was possible.".
            returns => [1];
    }

    # Accept the xcode licence
    exec {
        'xcode_license_agree':
            command => '/usr/bin/xcodebuild -license accept',
    }

}
