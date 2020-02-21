# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_shared::gpg_files (
    String $destination,
    String $file_name
){

    $srcloc      = lookup('win_ext_gpg_src')
    $gpg_command = "\"${facts['custom_win_programfilesx86']}\\GNU\\GnuPG\\pub\\gpg.exe\""
    $src_file    = "${facts['custom_win_systemdrive']}\\GPG\\${file_name}"
    $gpg_key    = "${facts['custom_win_systemdrive']}\\GPG\\${facts['custom_win_gw_workertype']}.gpg"

    file { $src_file:
        source   => "${srcloc}/${file_name}",
    }
    exec { "${file_name}_decrypt":
        command  => epp('win_shared/gpg_decrypt.ps1.epp'),
        provider => powershell,
    }
}

#  This predicated on having a gpg key in C:\GPG\ named $workerType.gpg
#  As well as the encrypted file in s3 at the location specified in hiera
#  This is a temporary hack that should not be left in place in nodes
