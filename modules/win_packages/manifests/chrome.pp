# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::chrome {

    $chrome_key       = "HKLM\\SOFTWARE\\Policies\\Google\\Chrome"
    $chrome_reg_value = [
                        "${chrome_key}\\MetricsReportingEnabled",
                        "${chrome_key}\\SafeBrowsingExtendedReportingEnabled",
                        "${chrome_key}\\ChromeCleanupReportingEnabled"
                        ]
    # This will install and update
    # Ref: https://bugzilla.mozilla.org/show_bug.cgi?id=1570767#c6
    # Existing installs will update automaticly
    # Check S3 tags for starting version
    # https://s3.console.aws.amazon.com/s3/object/ronin-puppet-package-repo/Windows/googlechromestandaloneenterprise64.msi?region=us-east-2&tab=properties
    win_packages::win_msi_pkg { 'Google Chrome':
        pkg             => 'googlechromestandaloneenterprise64.msi',
        install_options => ['/quiet'],
    }

    registry_key { 'HKLM\System\SOFTWARE\Policies\Google':
        ensure => present,
    }
    registry_key { $chrome_key:
        ensure => present,
    }
    # disable reporting back to google
    registry_value { $chrome_reg_value:
        ensure => present,
        type   => dword,
        data   => '0'
    }
}
# Reference https://cloud.google.com/docs/chrome-enterprise/policies for registry settings
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1570767
