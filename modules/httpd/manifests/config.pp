# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define httpd::config(
    String $content,
    Enum['present', 'absent'] $ensure = 'present',
) {
    include httpd
    include httpd::settings

    $file = "${httpd::settings::conf_d_dir}/${title}"

    if $ensure == 'absent' {
        file { $file:
            ensure => absent,
            notify => Service['httpd'],
        }
    } else {
        file { $file:
            notify    => Service['httpd'],
            mode      => $httpd::settings::mode,
            owner     => $httpd::settings::owner,
            group     => $httpd::settings::group,
            content   => $content,
            # don't show the diff, since sometimes httpd configs contain passwords
            show_diff => false;
        }
    }
}
