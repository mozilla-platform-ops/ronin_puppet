# TODO: see build-puppet/modules/vnc/manifests/init.pp

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_vnc {
  # include config
  # include users::builder
  include linux_packages::vnc_server
  include roles_profiles::profiles::cltbld_user

  if (lookup('cltbld_user.vnc_password') == '') {
    fail('No VNC password set')
  }
  file {
    "${roles_profiles::profiles::cltbld_user::homedir}/.vnc":
      ensure => directory,
      mode   => '0700',
      owner  => $roles_profiles::profiles::cltbld_user::username,
      group  => $roles_profiles::profiles::cltbld_user::group;
    "${roles_profiles::profiles::cltbld_user::homedir}/.vnc/passwd":
      ensure => absent;
    '/etc/vnc_passwdfile':
      ensure    => file,
      mode      => '0600',
      owner     => root,
      group     => root,
      content   => lookup('cltbld_user.vnc_password'),
      show_diff => false;
  }
  case $::operatingsystemrelease {
    18.04: {
      file {
        '/lib/systemd/system/x11vnc.service':
          content => template("${module_name}/x11vnc.service.erb");
      }
    }
    default: {
      fail ("Ubuntu ${::operatingsystemrelease} is not suported")
    }
  }
  # note that x11vnc isn't started automatically
}
