# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::chrome {
  include chocolatey
  $google_chrome_version = lookup('win-worker.googlechrome.version')

  ## Block googleupdate.exe to prevent installing an updating version of chrome outside of chocolatey
  windows_firewall::exception { 'googleupdate':
    ensure       => present,
    direction    => 'out',
    action       => 'block',
    enabled      => true,
    protocol     => 'TCP',
    display_name => 'BlockGoogleUpdate',
    description  => 'Blocks googleupdate.exe from checking for new versions of chrome',
    program      => 'C:\\Program Files (x86)\\Google\\Update\\GoogleUpdate.exe',
  }

  ## Registry path for google update 
  $googleupdate_key = "HKLM\\SOFTWARE\\Policies\\Google\\Update"
  registry_key { $googleupdate_key:
    ensure => present,
  }

  ## Registry path for google chrome
  $googlechrome_key = "HKLM\\SOFTWARE\\Policies\\Google\\Chrome"
  registry_key { $googlechrome_key:
    ensure => present,
  }

  $googlechrome_disable = [
    "${googlechrome_key}\\MetricsReportingEnabled", ## https://admx.help/?Category=Chrome&Policy=Google.Policies.Chrome::MetricsReportingEnabled
    "${googlechrome_key}\\SafeBrowsingExtendedReportingEnabled", ## https://admx.help/?Category=Chrome&Policy=Google.Policies.Chrome::SafeBrowsingExtendedReportingEnabled
    "${googlechrome_key}\\ChromeCleanupReportingEnabled", ## https://admx.help/?Category=Chrome&Policy=Google.Policies.Chrome::ChromeCleanupReportingEnabled
  ]

  $googleupdate_disable = [
    "${googleupdate_key}\\AutoUpdateCheckPeriodMinutes", ## Minutes between update checks https://admx.help/?Category=GoogleUpdate&Policy=Google.Policies.Update::Pol_AutoUpdateCheckPeriod
    "${googleupdate_key}\\UpdateDefault", ## Updates disabled https://admx.help/?Category=GoogleUpdate&Policy=Google.Policies.Update::Pol_DefaultUpdatePolicy 
    "${googleupdate_key}\\Update{8A69D345-D564-463C-AFF1-A69D9E530F96}", ## Updates disabled https://admx.help/?Category=GoogleUpdate&Policy=Google.Policies.Update::Pol_UpdatePolicyGoogleChrome
  ]

  $googleupdate_enable = [
    "${googleupdate_key}\\DisableAutoUpdateChecksCheckboxValue", ## http://googlesystem.blogspot.com/2009/05/customize-or-disable-google-update.html 
  ]

  registry_value { $googleupdate_disable:
    ensure => present,
    type   => dword,
    data   => '0',
  }

  registry_value { $googleupdate_enable:
    ensure => present,
    type   => dword,
    data   => '1',
  }

  registry_value { $googlechrome_disable:
    ensure => present,
    type   => dword,
    data   => '0',
  }

  ## Install the latest version of chrome via chocolatey
  package { 'googlechrome':
    ensure   => $google_chrome_version,
    provider => 'chocolatey',
  }

  ## Disable the google updater service
  exec { 'disable_google_update':
    command  => file('win_packages/disable_google_updater.ps1'),
    provider => powershell,
    require  => Package['googlechrome'],
  }
}
# Reference https://cloud.google.com/docs/chrome-enterprise/policies for registry settings
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1570767
# https://bugzilla.mozilla.org/show_bug.cgi?id=1876822
