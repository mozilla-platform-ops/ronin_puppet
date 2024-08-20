# gw_checker/manifests/init.pp

class macos_gw_checker (
  Boolean $enabled = true,
)
{

  # Ensure the gw_checker.sh script is present and executable
  file { '/usr/local/bin/gw_checker.sh':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'wheel',
    source => 'puppet:///modules/macos_gw_checker/gw_checker.sh',
  }

  # Ensure the cron job is present in root's crontab
  cron { 'gw_checker':
    ensure  => present,
    command => '/usr/local/bin/gw_checker.sh',
    user    => 'root',
    minute  => '*/30',
  }
}
