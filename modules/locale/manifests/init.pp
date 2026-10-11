# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Set up locale settings
class locale () {
  case $facts['os']['name'] {
    'Ubuntu': {
      include linux_packages::locales

      file {
        '/usr/local/share/ronin-puppet':
          ensure => directory,
          owner  => root,
          group  => root,
          mode   => '0755';
        '/usr/local/share/ronin-puppet/default-locale':
          ensure  => file,
          source  => 'puppet:///modules/locale/locale.ubuntu',
          owner   => root,
          group   => root,
          mode    => '0644',
          notify  => [Exec['generate-locales'], Exec['reconfigure-locales']],
          require => Package['locales'];
      }
      exec {
        'generate-locales':
          command     => '/usr/sbin/locale-gen en_US.UTF-8',
          refreshonly => true;
      }
      exec {
        'reconfigure-locales':
          command     => '/usr/sbin/dpkg-reconfigure --frontend=noninteractive locales',
          refreshonly => true;
        'install default locale':
          command => '/usr/bin/install -o root -g root -m 0644 /usr/local/share/ronin-puppet/default-locale /etc/default/locale',
          unless  => '/usr/bin/cmp -s /usr/local/share/ronin-puppet/default-locale /etc/default/locale',
          require => [File['/usr/local/share/ronin-puppet/default-locale'], Exec['reconfigure-locales']];
      }
    }
    default: {
      notice("Don't know how to set up locale on ${facts['os']['name']}.")
    }
  }
}
