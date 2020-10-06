# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build (
    String $current_mozbld_ver,
    String $needed_mozbld_ver,
    String $current_hg_ver,
    String $needed_hg_ver,
    String $current_py3_pip_ver,
    String $needed_py3_pip_ver,
    String $current_py3_zstandard_ver,
    String $needed_py3_zstandard_ver,
    String $install_path,
    String $system_drive,
    String $cache_drive,
    String $program_files,
    String $programdata,
    String $psutil_ver,
    String $tempdir,
    String $system32,
    String $external_source,
    String $builds_dir,
    $tooltool_tok = undef
) {

    if $::operatingsystem == 'Windows' {
        include win_mozilla_build::install
        include win_mozilla_build::hg_install
        include win_mozilla_build::hg_files
        include win_mozilla_build::install_py3_certi
        include win_mozilla_build::tooltool
        include win_mozilla_build::modifications
        include win_mozilla_build::set_registry_priority
        include win_mozilla_build::virtualenv_support
        include win_mozilla_build::pip
        include win_mozilla_build::grant_symlnk_access
        include win_mozilla_build::zstandard
        include win_mozilla_build::psutil
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
