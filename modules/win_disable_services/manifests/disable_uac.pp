# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# https://woshub.com/user-account-control-slider-and-group-policy-settings/

class win_disable_services::disable_uac {
  case $facts['custom_win_os_version'] {
    'win_11_2009':{
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\ConsentPromptBehaviorAdmin':
        type => dword,
        data => '0',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\ConsentPromptBehaviorUser':
        type => dword,
        data => '3',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableInstallerDetection':
        type => dword,
        data => '1',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableLUA':
        type => dword,
        data => '1',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableVirtualization':
        type => dword,
        data => '1',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\PromptOnSecureDesktop':
        type => dword,
        data => '0',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\ValidateAdminCodeSignatures':
        type => dword,
        data => '0',
      }
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\FilterAdministratorToken':
        type => dword,
        data => '0',
      }
    }
    'win_2022_2009':{
      registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableLUA':
        type => dword,
        data => '0',
      }
    }
    default: {
      warning("${module_name} does not support ${$facts['custom_win_os_version']}")
    }
  }
}
