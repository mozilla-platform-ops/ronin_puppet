# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build (
    $current_mozbld_ver = undef,
    $needed_mozbld_ver  = undef,
    $current_hg_ver     = undef,
    $needed_hg_ver      = undef,
    $install_path       = undef,
    $system_drive       = undef,
    $cache_drive        = undef,
    $program_files      = undef,
    $programdata        = undef,
    $tempdir            = undef,
    $system32           = undef
){

    if $::operatingsystem == 'Windows' {
        include win_mozilla_build::install
        include win_mozilla_build::hg_install
        include win_mozilla_build::hg_files
        include win_mozilla_build::tooltool
        include win_mozilla_build::modifications
        include win_mozilla_build::set_registry_priority
        include win_mozilla_build::virtualenv_support
        include win_mozilla_build::pip
        win_mozilla_build::grant_symlnk_access
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
