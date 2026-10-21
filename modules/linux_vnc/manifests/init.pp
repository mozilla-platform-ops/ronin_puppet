# TODO: see build-puppet/modules/vnc/manifests/init.pp

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_vnc (
    String $user,
    String $group,
    String $user_homedir,
    String $user_password,
) {
  include linux_packages::vnc_server

  file {
    "${user_homedir}/.vnc":
      ensure => directory,
      mode   => '0700',
      owner  => $user,
      group  => $group;
    "${user_homedir}/.vnc/passwd":
      ensure => absent;
    '/etc/vnc_passwdfile':
      ensure    => file,
      mode      => '0600',
      owner     => root,
      group     => root,
      content   => $user_password,
      show_diff => false;
  }
  case $facts['os']['release']['full'] {
    '18.04', '22.04', '24.04': {
      file {
        '/lib/systemd/system/x11vnc.service':
          ensure  => file,
          owner   => root,
          group   => root,
          mode    => '0644',
          content => template("${module_name}/x11vnc.service.erb"),
          notify  => Exec['reload systemd for x11vnc'];
      }
      exec { 'reload systemd for x11vnc':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
      }
    }
    default: {
      fail ("Ubuntu ${facts['os']['release']['full']} is not suported")
    }
  }
  # note that x11vnc isn't started automatically
}
