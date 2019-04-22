:

class mozilla_bitbar::systemd_reload {

  exec { '/usr/bin/systemctl daemon-reload':
    refreshonly => true,
  }

}
