# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_mercurial {
  include shared
  include linux_packages::mercurial

  $hgext_dir       = '/usr/local/lib/hgext'
  $hgrc            = '/etc/mercurial/hgrc'
  $hgrc_parentdirs = ['/etc/mercurial']

  # setup ext dir
  file {
      default: * => $::shared::file_defaults;

      $hgext_dir:
          ensure => directory,
          mode   => '0755';

      $hgrc_parentdirs:
          ensure => directory,
          mode   => '0755';

      $hgrc:
          ensure => file,
          source => 'puppet:///modules/linux_mercurial/hgrc',
          mode   => '0644';

    '/etc/mercurial/cacert.pem':
        ensure => file,
        source => 'puppet:///modules/linux_mercurial/cacert.pem';
  }

    # conflicts with /etc/mercurial/hgrc
    file {
        '/home/cltbld/.hgrc':
            ensure => absent;
    }

  # robust checkout
  file { "${hgext_dir}/robustcheckout.py":
      source => 'puppet:///modules/linux_mercurial/robustcheckout.py',
  }

  # bundle clone
  # - bundleclone: https://hg.mozilla.org/hgcustom/version-control-tools/
  file { "${hgext_dir}/bundleclone.py":
      source => 'puppet:///modules/linux_mercurial/bundleclone.py',
  }

}
