# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_talos () {
  case $::operatingsystem {
    'Ubuntu': {
      include linux_packages::nodejs
      include linux_packages::xvfb
      include linux_packages::llvm
      include linux_packages::sox
      include linux_packages::libxcb1
      include linux_packages::gstreamer

      # see bug 914627
      include linux_packages::git
      # # required for the 32-bit reftests per :ahal, bug 837268
      include linux_packages::ia32libs

      # setup sound modules
      # TODO: pull these two packages out and contain them in the kernelmodule defined type?
      # this provides lsmod and modprobe (maybe only missing on VM's?)
      package { 'kmod' :
          ensure => latest
      }
      # modprobe fails without this
      package { 'linux-generic' :
        ensure => latest
      }

      kernelmodule {
        'v4l2loopback':
          packages => ['v4l2loopback-dkms'];
      }

      # directories expected by talos
      file {
        [ '/builds',
          '/builds/slave',
          '/builds/slave/talos-data',
          '/builds/slave/talos-data/talos',
          '/builds/git-shared',
          '/builds/hg-shared',
          '/builds/tooltool_cache' ]:
          ensure => directory,
          # TODO: replace with hiera lookup
          owner  => 'cltbld',
          group  => 'staff',
          mode   => '0755',
      }
    }
    default: {
      fail("${module_name} not supported under ${::operatingsystem}")
    }
  }
}
