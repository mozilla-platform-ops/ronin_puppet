# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This class installs the latest Google Chrome on Ubuntu.
class linux_packages::google_chrome () {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          # Ensure apt is included
          include apt

          $postinst_script = '/usr/local/sbin/g_c_install.sh'

          # ordering
          Exec['install_repo'] -> Exec['apt_update'] -> Package['google-chrome-stable']

          # send the post inst script to the host
          file { $postinst_script:
            ensure  => file,
            content => file('linux_packages/google_chrome/install_repo'),
            owner   => 'root',
            group   => 'root',
            mode    => '0700',
          }

          # exec the postinst script if the apt repo is not already present
          exec { 'install_repo':
            command => $postinst_script,
            path    => ['/usr/local/sbin', '/bin', '/usr/bin'],
            require => File[$postinst_script],
            unless  => 'test -f /etc/apt/sources.list.d/google-chrome.list',
          }

          # the deb we're installing includes a cron
          # TODO: write test to check for the cron

          # Install Google Chrome stable version
          package { 'google-chrome-stable':
            ensure => 'latest',
          }
        }
        default: {
          fail("Cannot install Google Chrome on ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("Cannot install Google Chrome on ${facts['os']['name']}")
    }
  }
}
