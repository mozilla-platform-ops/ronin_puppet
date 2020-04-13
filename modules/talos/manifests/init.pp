# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class talos (
    String $user,
) {
    case $::operatingsystem {
        'Darwin': {

            include httpd
            include packages::java_developer_package_for_osx
            include packages::xcode_cmd_line_tools
            require dirs::builds

            file {
                [ '/builds/slave',
                  '/builds/slave/talos-data',
                  '/builds/slave/talos-data/talos',
                  '/builds/git-shared',
                  '/builds/hg-shared',
                  '/builds/tooltool_cache' ]:
                    ensure => directory,
                    owner  => $user,
                    group  => 'staff',
                    mode   => '0755',
            }

            $document_root = '/builds/slave/talos-data/talos'
            httpd::config { 'talos.conf':
                content => template('talos/talos-httpd.conf.erb'),
            }
        }
        default: {
            fail("${module_name} not supported under ${::operatingsystem}")
        }
    }
}
