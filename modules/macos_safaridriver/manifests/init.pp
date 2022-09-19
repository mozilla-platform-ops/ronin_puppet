class macos_safaridriver {
  case $facts['os']['name'] {
    'Darwin': {
      $the_script = '/usr/local/bin/add-safari-permissions.sh'

      file { $the_script:
        content => file('macos_safaridriver/mac_desktop_image.py'),
      }

      exec { 'execute script':
        command => $the_script,
        require => File[$the_script],
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
