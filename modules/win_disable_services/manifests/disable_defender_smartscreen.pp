class win_disable_services::disable_defender_smartscreen {

  # 1) Shell/Explorer SmartScreen (policy) - MUST set ShellSmartScreenLevel explicitly
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System\EnableSmartScreen':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  # Do NOT set absent; set "Off"
  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System\ShellSmartScreenLevel':
    ensure => present,
    type   => string,
    data   => 'Off',
  }

  # 2) Explorer non-policy setting (some builds still consult this)
  registry_key { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled':
    ensure => present,
    type   => string,
    data   => 'Off',
  }

  # 3) Edge SmartScreen (optional, but harmless to include)
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Edge':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Edge\SmartScreenEnabled':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Edge\SmartScreenPuaEnabled':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  # 4) Store apps / AppHost web content evaluation
  registry_key { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost\EnableWebContentEvaluation':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  # 5) Force policy refresh + restart Explorer (often required for the setting to “take”)
  exec { 'gpupdate_force':
    command   => 'cmd.exe /c gpupdate /force',
    provider  => powershell,
    logoutput => true,
    require   => [
      Registry_value['HKLM\SOFTWARE\Policies\Microsoft\Windows\System\EnableSmartScreen'],
      Registry_value['HKLM\SOFTWARE\Policies\Microsoft\Windows\System\ShellSmartScreenLevel'],
    ],
  }

  exec { 'restart_explorer':
    command   => 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Process explorer.exe"',
    provider  => powershell,
    logoutput => true,
    require   => Exec['gpupdate_force'],
  }
}
