# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::chrome {
  include chocolatey

  $chrome_key       = "HKLM\\SOFTWARE\\Policies\\Google\\Chrome"
  $chrome_reg_value = [
    "${chrome_key}\\MetricsReportingEnabled",
    "${chrome_key}\\SafeBrowsingExtendedReportingEnabled",
    "${chrome_key}\\ChromeCleanupReportingEnabled",
  ]
  package { 'googlechrome':
    ensure   => latest,
    provider => 'chocolatey',
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
    data   => '0',
  }
}
# Reference https://cloud.google.com/docs/chrome-enterprise/policies for registry settings
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1570767
# https://bugzilla.mozilla.org/show_bug.cgi?id=1876822
