# TODO: set up pip.conf for root user

file {
  '/root/.pip':
    ensure => directory,
    group  => 'root',
    mode   => '0755',
    owner  => 'root';

  '/root/.pip/pip.conf':
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => "puppet:///modules/${module_name}/pip.conf";
}
