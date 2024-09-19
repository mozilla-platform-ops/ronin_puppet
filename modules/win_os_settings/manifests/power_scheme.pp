class win_os_settings::power_scheme {
  ## It seems that the hardware workers have ultimate performance
  ## While the cloud workers only have high performance.
  ## Let's hardcode the guid based on the location
  case $facts['custom_win_location'] {
    'datacenter': {
      $guid = 'e9a42b02-d5df-448d-aa00-03f14749eb61' # Ultimate Performance
    }
    default: {
      $guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' # High Performance
    }
  }

  # Use POWERCFG.EXE to set the desired power scheme.
  exec { 'windows-powercfg':
    command  => "POWERCFG -SETACTIVE ${guid}",
    unless   => template('windows/powercfg_check.ps1.erb'),
    provider => 'powershell',
  }
}
