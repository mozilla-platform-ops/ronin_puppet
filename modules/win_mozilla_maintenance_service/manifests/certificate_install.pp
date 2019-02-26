# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_mozilla_maintenance_service::certificate_install (
$cert_key=$cert_key,
$registry_name=$registry_name,
$registry_issuer=$registry_issuer,
$cert=$title
){

require win_mozilla_maintenance_service::install

$local_dir       = $facts['custom_win_roninprogramdata']
$certutil_exe    = "${facts['custom_win_system32']}\\certutil.exe"
$maintenance_key = $win_mozilla_maintenance_service::maintenance_key

    file { "${local_dir}\\${cert}.cer":
        content => file("win_mozilla_maintenance_service/${cert}.cer"),
    }
    exec { "install_${cert}":
        command     => "${certutil_exe} -addstore Root ${local_dir}\\${cert}.cer",
        subscribe   => File["${local_dir}\\${cert}.cer"],
        refreshonly => true,
    }

    registry_key { "${maintenance_key}\\${cert_key}":
        ensure => present,
    }
    registry_value { "${maintenance_key}\\${cert_key}\\name":
        ensure => present,
        type   => string,
        data   => $registry_name,
    }
    registry_value { "${maintenance_key}\\${cert_key}\\issuer":
        ensure => present,
        type   => string,
        data   => $registry_issuer,
    }
    registry_value { "${maintenance_key}\\${cert_key}\\programName":
        ensure => present,
        type   => string,
        data   => '',
    }
    registry_value { "${maintenance_key}\\${cert_key}\\publisherLink":
        ensure => present,
        type   => string,
        data   => '',
    }
}
