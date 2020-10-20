# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_mercurial {
  include shared
  include linux_packages::mercurial

  $hgext_dir       = '/usr/local/lib/hgext'
  $hgrc            = '/etc/mercurial/hgrc.d/mozilla.rc'
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
  }

  # robust checkout
  file { "${hgext_dir}/robustcheckout.py":
      source => 'puppet:///modules/linux_mercurial/robustcheckout.py',
  }
}
