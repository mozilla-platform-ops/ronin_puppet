# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_system_settings (
  Boolean $enabled = true,
) {
  # Detect macOS version
  $macos_version = regsubst(fact('os.release.major'), '^(\\d+)$', '\1')

  # Apply settings to macOS 14 and 15
  if $enabled and ($macos_version == '14' or $macos_version == '15') {
    notify { "Applying macOS ${macos_version} system settings...": }

    # Disable macOS Screen Saver
    exec { 'Disable Screen Saver':
      command => '/usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 0',
      unless  => '/usr/bin/defaults -currentHost read com.apple.screensaver idleTime | grep 0',
    }

    # Disable macOS Software Updates
    exec { 'Disable Software Update Checks':
      command => '/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false',
      unless  => '/usr/bin/defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled | grep false',
    }

    exec { 'Disable Automatic Download of Updates':
      command => '/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false',
      unless  => '/usr/bin/defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload | grep false',
    }

    exec { 'Disable Automatic Installation of macOS Updates':
      command => '/usr/bin/defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false',
      unless  => '/usr/bin/defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates | grep false',
    }

    # Disable macOS Power Management (Prevent Sleep, Enable Wake-on-LAN)
    exec { 'Disable System Sleep':
      command => '/usr/bin/pmset -a sleep 0',
      unless  => "/usr/bin/pmset -g | grep ' sleep' | grep 0",
    }

    exec { 'Disable Display Sleep':
      command => '/usr/bin/pmset -a displaysleep 0',
      unless  => "/usr/bin/pmset -g | grep ' displaysleep' | grep 0",
    }

    exec { 'Disable Disk Sleep':
      command => '/usr/bin/pmset -a disksleep 0',
      unless  => "/usr/bin/pmset -g | grep ' disksleep' | grep 0",
    }

    exec { 'Enable Wake on Network Access':
      command => '/usr/bin/pmset -a womp 1',
      unless  => "/usr/bin/pmset -g | grep ' womp' | grep 1",
    }

    exec { 'Enable Auto Restart on Power Loss':
      command => '/usr/bin/pmset -a autorestart 1',
      unless  => "/usr/bin/pmset -g | grep ' autorestart' | grep 1",
    }

    # Disable macOS Firewall
    exec { 'Disable macOS Firewall':
      command => '/usr/bin/defaults write /Library/Preferences/com.apple.alf globalstate -int 0',
      unless  => '/usr/bin/defaults read /Library/Preferences/com.apple.alf globalstate | grep 0',
    }
  }

  # Apply "Skip Welcome to Mac" setting ONLY for macOS 15
  if $enabled and $macos_version == '15' {
    notify { 'Applying macOS 15 Welcome Screen settings...': }

    exec { 'Skip Welcome to Mac Setup Assistant':
      command => "/usr/bin/defaults write /Library/Preferences/com.apple.SetupAssistant.managed SkipSetupItems -array-add 'Welcome'",
      unless  => "/usr/bin/defaults read /Library/Preferences/com.apple.SetupAssistant.managed SkipSetupItems | grep 'Welcome'",
    }

    notify { 'Applying macOS 15 Window Manager settings...': }

    exec { 'Disable Window Manager - EnableTiledWindowMargins':
      command => '/usr/bin/defaults write /Users/cltbld/Library/Preferences/com.apple.WindowManager EnableTiledWindowMargins -bool false',
      user    => 'cltbld',
      unless  => '/usr/bin/defaults read /Users/cltbld/Library/Preferences/com.apple.WindowManager EnableTiledWindowMargins | grep false',
    }

    exec { 'Disable Window Manager - EnableTilingByEdgeDrag':
      command => '/usr/bin/defaults write /Users/cltbld/Library/Preferences/com.apple.WindowManager EnableTilingByEdgeDrag -bool false',
      user    => 'cltbld',
      unless  => '/usr/bin/defaults read /Users/cltbld/Library/Preferences/com.apple.WindowManager EnableTilingByEdgeDrag | grep false',
    }

    notify { 'Applying macOS 15 Screen Capture Alert Bypass...': }

    exec { 'Bypass Screen Capture Alert':
      command => '/usr/bin/defaults write /Library/Preferences/com.apple.applicationaccess forceBypassScreenCaptureAlert -bool true',
      unless  => '/usr/bin/defaults read /Library/Preferences/com.apple.applicationaccess forceBypassScreenCaptureAlert | grep true',
    }
  }
}
