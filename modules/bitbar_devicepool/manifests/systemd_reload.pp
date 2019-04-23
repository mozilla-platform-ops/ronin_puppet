class bitbar_devicepool::systemd_reload {

  exec { '/bin/systemctl daemon-reload':
    refreshonly => true,
  }

}
