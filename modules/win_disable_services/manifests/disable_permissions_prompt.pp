# Class: win_disable_services::disable_permissions_prompt
# 
# This class disables the permissions prompt for the microphone in Windows.
#
class win_disable_services::disable_permissions_prompt {
  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone':
    ensure => present,
    type   => string,
    data   => 'Allow',
  }

  ## Required for Mochitest browser-chrome run from msix packages 
  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\Mozilla.Firefox.MSIX':
    ensure => present,
    type   => string,
    data   => 'Allow',
  }
}
