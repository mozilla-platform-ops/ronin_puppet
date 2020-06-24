# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mozilla_build {

    case $::operatingsystem {
        'Windows': {

        # Current versions Determined in /modules/win_shared/facts.d/facts_win_mozilla_build.ps1
            $cache_drive  = $facts['custom_win_location'] ? {
                'aws'   => 'y:',
                default => $facts['custom_win_systemdrive'],
            }
            # tooltool token is not needed with worker-runner
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1624900#c1
            # As worker-runner support is expanded this conditional will expand as well
            # Once worker-runner is fully implemented then this support can be removed
            $tooltool_tok = $facts['custom_win_location'] ? {
                'azure' => undef,
                default => lookup('tooltool_tok')
            }

            class { 'win_mozilla_build':
                current_mozbld_ver        => $facts['custom_win_mozbld_vesion'],
                needed_mozbld_ver         => lookup('win-worker.mozilla_build.version'),
                current_hg_ver            => $facts['custom_win_hg_version'],
                needed_hg_ver             => lookup('win-worker.mozilla_build.hg_version'),
                current_py3_pip_ver       => $facts['custom_win_py3_pip_version'],
                needed_py3_pip_ver        => lookup('win-worker.mozilla_build.py3_pip_version'),
                current_py3_zstandard_ver => $facts['custom_win_py3_zstandard_version'],
                needed_py3_zstandard_ver  => lookup('win-worker.mozilla_build.py3_zstandard_version'),
                install_path              => "${facts['custom_win_systemdrive']}\\mozilla-build",
                system_drive              => $facts['custom_win_systemdrive'],
                cache_drive               => $cache_drive,
                program_files             => $facts['custom_win_programfiles'],
                programdata               => $facts['custom_win_programdata'],
                tempdir                   => $facts['custom_win_temp_dir'],
                system32                  => $facts['custom_win_system32'],
                external_source           => lookup('windows.s3.ext_pkg_src'),
                builds_dir                => "${facts['custom_win_systemdrive']}\\builds",
                tooltool_tok              => $tooltool_tok,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524440
            # Mozilla Build Version
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1461340
            # Hg version
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1490703
            # Symlinks Support
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1316329
            # Pip upgrade / zstandard
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1570711

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
