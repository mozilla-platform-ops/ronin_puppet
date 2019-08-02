class bitbar_devicepool::other_repos {

  vcsrepo { '/home/bitbar/android-tools':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/mozilla-platform-ops/android-tools.git',
    user     => 'bitbar',
  }

}
