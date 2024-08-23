# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class talos (
  String $user,
) {
  case $facts['os']['name'] {
    'Darwin': {
      $builds_dir = $facts['os']['macosx']['version']['major'] ? {
        '10.15' => '/builds',
        default => '/opt/builds'
      }

      include httpd
      include packages::java_developer_package_for_osx
      include macos_xcode_tools
      require dirs::builds

      file {
        ["${builds_dir}/slave",
          "${builds_dir}/slave/talos-data",
          "${builds_dir}/slave/talos-data/talos",
          "${builds_dir}/git-shared",
          "${builds_dir}/hg-shared",
        "${builds_dir}/tooltool_cache"]:
          ensure => directory,
          owner  => $user,
          group  => 'staff',
          mode   => '0755',
      }

      $document_root = "${builds_dir}/slave/talos-data/talos"
      httpd::config { 'talos.conf':
        content => template('talos/talos-httpd.conf.erb'),
      }
    }
    default: {
      fail("${module_name} not supported under ${facts['os']['name']}")
    }
  }
}
