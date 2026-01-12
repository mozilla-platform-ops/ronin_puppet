class win_disable_services::disable_defender_smartscreen {

  ## 1) Shell/Explorer SmartScreen (policy)
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System\EnableSmartScreen':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System\ShellSmartScreenLevel':
    ensure => absent,
  }

  ## 2) Explorer non-policy setting (per NinjaOne)
  registry_key { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled':
    ensure => present,
    type   => string,
    data   => 'Off',
  }

  ## 3) Edge SmartScreen (official Edge policy)
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Edge':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Edge\SmartScreenEnabled':
    ensure => present,
    type   => dword,
    data   => '0',
  }

  ## 4) Store apps / AppHost web content evaluation
  registry_key { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost':
    ensure => present,
  }

  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost\EnableWebContentEvaluation':
    ensure => present,
    type   => dword,
    data   => '0',
  }
}
