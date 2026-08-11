# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs the BlackHole virtual audio drivers.
#
# These are deliberately NOT installed via packages::macos_package_from_s3 /
# the pkgdmg provider. BlackHole's postinstall script ends with
#
#   launchctl kickstart -k system/com.apple.audio.coreaudiod
#
# which SIP denies ("Operation not permitted"). That makes postinstall exit
# non-zero, so PackageKit reports Code=112 and /usr/sbin/installer returns 1 --
# even though the driver payload has already been staged to
# /Library/Audio/Plug-Ins/HAL by that point. The pkgdmg provider treats that
# exit code as a hard failure, never writes its receipt marker, and retries on
# every run, so run-puppet.sh loops forever on a SIP-enabled host.
#
# So: install by hand and treat *payload presence* as the success criterion
# rather than installer's exit code. A genuine payload failure still fails the
# exec, because the driver directory won't exist.
#
# Registering the driver with coreaudio still needs the daemon restarted. On a
# SIP-disabled host we do it here; on a SIP-enabled host the kickstart is
# denied and the driver registers on the next reboot instead. CI workers reboot
# between tasks, so that resolves on its own.
class packages::virt_audio_s3 (
    String $version = '0.5.0',
){

    include shared
    require packages::setup

    packages::virt_audio_driver { 'BlackHole2ch':
        version => $version,
    }
    packages::virt_audio_driver { 'BlackHole16ch':
        version => $version,
    }

    exec { 'register virtual audio drivers with coreaudio':
        command     => '/bin/launchctl kickstart -k system/com.apple.audio.coreaudiod',
        refreshonly => true,
        # Denied under SIP; the driver registers on the next reboot instead.
        returns     => [0, 1],
    }
}
