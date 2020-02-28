# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_talos () {
  case $::operatingsystem {
    'Ubuntu': {

      # TODO: httpd

      include linux_packages::nodejs
      include linux_packages::xvfb
      include linux_packages::llvm
      include linux_packages::sox

      # see bug 914627
      include linux_packages::system_git
      # # required for the 32-bit reftests per :ahal, bug 837268
      include linux_packages::ia32libs

      # setup sound modules
      # this provides lsmod and modprobe (maybe only missing on VM's?)
      package { 'kmod' :
          ensure => latest
      }
      kernelmodule {
        'snd_aloop':
          packages => ['libasound2'];
        'v4l2loopback':
          packages => ['v4l2loopback-dkms'];
      }

      # TODO: all below
      # # Ubuntu specific packages
      # include packages::libxcb1
      # include packages::gstreamer
      # include tweaks::cron
      # include tweaks::resolvconf
      # case $::hardwaremodel {
      #   # We only run Android x86 emulator kvm jobs on
      #   # 64-bit host machines
      #   'x86_64': {
      #     include packages::cpu_checker
      #     include packages::qemu_kvm
      #     include packages::bridge_utils
      #   }
      # }
      #

      ###### FROM OS X TALOS IN THIS REPO
      # include httpd
      # include packages::java_developer_package_for_osx
      # include packages::xcode_cmd_line_tools
      # require dirs::builds
      #
      # file {
      #   [ '/builds/slave',
      #     '/builds/slave/talos-data',
      #     '/builds/slave/talos-data/talos',
      #     '/builds/git-shared',
      #     '/builds/hg-shared',
      #     '/builds/tooltool_cache' ]:
      #     ensure  => directory,
      #     owner   => $user,
      #     group   => 'staff',
      #     mode    => '0755',
      #     require => User[$user],
      # }
      #
      # $document_root = '/builds/slave/talos-data/talos'
      # httpd::config { 'talos.conf':
      #   content => template('talos/talos-httpd.conf.erb'),

    }
    default: {
      fail("${module_name} not supported under ${::operatingsystem}")
    }
  }
}

