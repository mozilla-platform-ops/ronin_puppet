# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Retire the legacy watchdog on hosts where it was installed. Stopping the
# timer before removing its unit files also handles existing workers.
class linux_generic_worker::check_gw () {
  if $facts['os']['name'] == 'Ubuntu' {
    exec { 'disable check_gw timer':
      command => '/bin/systemctl disable --now check_gw.timer',
      onlyif  => '/usr/bin/test -e /lib/systemd/system/check_gw.timer',
    }

    file { [
      '/lib/systemd/system/check_gw.timer',
      '/lib/systemd/system/check_gw.service',
    ]:
      ensure  => absent,
      require => Exec['disable check_gw timer'],
      notify  => Exec['reload systemd'];

    '/opt/relops-check_gw/check_gw.py':
      ensure  => absent,
      require => Exec['disable check_gw timer'];
    }
  }
}
