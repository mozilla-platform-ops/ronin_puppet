# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs a single BlackHole virtual audio driver from the ronin S3 package
# repo. See packages::virt_audio_s3 for why this does not use the pkgdmg
# provider.
#
# @param version BlackHole release to install, e.g. '0.5.0'.
define packages::virt_audio_driver (
    String $version,
) {

    include shared
    require packages::setup

    $pkg         = "${title}.v${version}.pkg"
    $local_pkg   = "/var/tmp/${pkg}"
    $driver_path = "/Library/Audio/Plug-Ins/HAL/${title}.driver"
    $source      = "https://${packages::setup::default_s3_domain}/${packages::setup::default_bucket}/macos/public/common/${pkg}"

    file {
        default: * => $::shared::file_defaults;

        $local_pkg:
            ensure => 'file',
            source => $source,
            mode   => '0644';
    }

    # installer's exit code is deliberately discarded -- see the class docs.
    # `test -d` is the real success criterion, so a payload that never lands
    # still fails the exec.
    exec { "install ${pkg}":
        command => "/usr/sbin/installer -pkg ${local_pkg} -target / ; test -d ${driver_path}",
        path    => ['/bin', '/usr/bin', '/usr/sbin'],
        creates => $driver_path,
        require => File[$local_pkg],
        notify  => Exec['register virtual audio drivers with coreaudio'],
    }
}
