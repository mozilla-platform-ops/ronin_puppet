# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mozbuild_post_boostrap {

    case $::operatingsystem {
        'Windows': {

            # Current versions Determined in /modules/win_shared/facts.d/facts_win_mozilla_build.ps1

            case $facts['custom_win_os_version'] {
                'win_2022_2009': {
                    if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
                        $cache_drive  = 'd:'
                    } else {
                        $cache_drive  = $facts['custom_win_systemdrive']
                    }
                }
                default: {
                    if ($facts['custom_win_location'] == 'azure') and ($facts['custom_win_bootstrap_stage'] == 'complete') {
                        $cache_drive  = 'y:'
                    } else {
                        $cache_drive  = $facts['custom_win_systemdrive']
                    }
                }
            }

            # tooltool token is not needed with worker-runner
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1624900#c1
            # As worker-runner support is expanded this conditional will expand as well
            # Once worker-runner is fully implemented then this support can be removed
            $tooltool_tok = $facts['custom_win_location'] ? {
                'azure' => undef,
                default => lookup('tooltool_tok')
            }

            class { 'win_mozilla_build::post_boostrap':
                install_path  => "${facts['custom_win_systemdrive']}\\mozilla-build",
                system_drive  => $facts['custom_win_systemdrive'],
                cache_drive   => $cache_drive,
                program_files => $facts['custom_win_programfiles'],
                programdata   => $facts['custom_win_programdata'],
                tempdir       => $facts['custom_win_temp_dir'],
                system32      => $facts['custom_win_system32'],
                builds_dir    => "${facts['custom_win_systemdrive']}\\builds",
                tooltool_tok  => $tooltool_tok,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
