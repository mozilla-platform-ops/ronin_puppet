# TODO: set up pip.conf for root user

class linux_python () {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04' : {
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
        }
        default: {
          fail("Unrecognized Ubuntu version ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("Not supported on ${facts['os']['name']}")
    }
  }
}
