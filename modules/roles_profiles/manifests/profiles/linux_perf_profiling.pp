# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs the linux-tools package (provides `perf`) and grants cltbld
# sudo access to run it. Used by Linux talos roles to support performance
# profiling investigations (bug 2031822).
class roles_profiles::profiles::linux_perf_profiling {

  require linux_packages::linux_tools

  file { '/usr/local/bin/record-system-perf':
    ensure => file,
    source => 'puppet:///modules/linux_packages/record-system-perf',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/var/lib/record-system-perf':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  sudo::custom { 'allow_cltbld_record_system_perf':
    user    => 'cltbld',
    command => '/usr/local/bin/record-system-perf ""',
  }

  # Remove after Firefox's Raptor callers migrate to record-system-perf (LS-002).
  sudo::custom { 'allow_cltbld_perf':
    user    => 'cltbld',
    command => '/usr/bin/perf',
  }

}
