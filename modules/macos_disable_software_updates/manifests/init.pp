# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Disables automatic macOS software updates by writing directly to the
# com.apple.SoftwareUpdate preferences domain as root.  This replaces
# the MDM/mobileconfig profile approach and works on macOS 10.15 and later.
#
# ConfigDataInstall and CriticalUpdateInstall are intentionally left enabled
# so that XProtect / MRT security-data updates continue to be applied.
class macos_disable_software_updates {

    $domain = '/Library/Preferences/com.apple.SoftwareUpdate'

    macos_utils::defaults { 'softwareupdate_AutomaticCheckEnabled':
        domain   => $domain,
        key      => 'AutomaticCheckEnabled',
        value    => '0',
        val_type => 'bool',
    }

    macos_utils::defaults { 'softwareupdate_AutomaticDownload':
        domain   => $domain,
        key      => 'AutomaticDownload',
        value    => '0',
        val_type => 'bool',
    }

    macos_utils::defaults { 'softwareupdate_AutomaticallyInstallAppUpdates':
        domain   => $domain,
        key      => 'AutomaticallyInstallAppUpdates',
        value    => '0',
        val_type => 'bool',
    }

    macos_utils::defaults { 'softwareupdate_AutomaticallyInstallMacOSUpdates':
        domain   => $domain,
        key      => 'AutomaticallyInstallMacOSUpdates',
        value    => '0',
        val_type => 'bool',
    }

    macos_utils::defaults { 'softwareupdate_AllowPreReleaseInstallation':
        domain   => $domain,
        key      => 'AllowPreReleaseInstallation',
        value    => '0',
        val_type => 'bool',
    }

    macos_utils::defaults { 'softwareupdate_ConfigDataInstall':
        domain   => $domain,
        key      => 'ConfigDataInstall',
        value    => '1',
        val_type => 'bool',
    }

    macos_utils::defaults { 'softwareupdate_CriticalUpdateInstall':
        domain   => $domain,
        key      => 'CriticalUpdateInstall',
        value    => '1',
        val_type => 'bool',
    }
}
