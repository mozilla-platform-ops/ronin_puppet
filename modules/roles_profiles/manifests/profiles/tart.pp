# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs Tart, pulls an OCI VM image, clones N worker VMs, and manages
# per-VM LaunchAgents so they start and stay running as the configured user.
class roles_profiles::profiles::tart {
  $version        = lookup('tart.version',        String,  'first', '2.30.0')
  $registry_host  = lookup('tart.registry_host',  String,  'first', '10.49.56.83')
  $registry_port  = lookup('tart.registry_port',  Integer, 'first', 5000)
  $oci_image      = lookup('tart.oci_image',      String,  'first', 'sequoia-gecko1b-vms')
  $oci_tag        = lookup('tart.oci_tag',        String,  'first', 'prod-latest')
  $vm_name_prefix = lookup('tart.vm_name_prefix', String,  'first', 'gecko1b-vm')
  $worker_count   = lookup('tart.worker_count',   Integer, 'first', 2)
  $insecure       = lookup('tart.insecure',       Boolean, 'first', true)
  $user           = lookup('tart.user',           String,  'first', 'admin')

  $install_dir   = '/Applications'
  $bin_path      = '/usr/local/bin/tart'
  $tart_url      = "https://github.com/cirruslabs/tart/releases/download/${version}/tart.tar.gz"
  $insecure_flag = $insecure ? { true => '--insecure', false => '' }

  exec { 'create_usr_local_bin':
    command => 'mkdir -p /usr/local/bin',
    path    => ['/usr/bin', '/bin'],
    unless  => 'test -d /usr/local/bin',
  }

  exec { 'install_tart':
    command => "/bin/bash -c 'set -e && tmp=\$(mktemp -d) && cd \"\$tmp\" && curl -L -o tart.tar.gz ${tart_url} && tar -xzf tart.tar.gz && rm -rf ${install_dir}/Tart.app && mv Tart.app ${install_dir}/Tart.app && (xattr -dr com.apple.quarantine ${install_dir}/Tart.app || true) && mkdir -p /usr/local/bin && ln -sf ${install_dir}/Tart.app/Contents/MacOS/tart ${bin_path} && cd / && rm -rf \"\$tmp\"'",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    unless  => "test -x ${bin_path}",
    timeout => 600,
    require => Exec['create_usr_local_bin'],
  }

  file { '/usr/local/bin/tart-pull-image.sh':
    ensure  => file,
    mode    => '0755',
    content => epp('roles_profiles/tart/tart-pull-image.sh.epp', {
      registry_host  => $registry_host,
      registry_port  => $registry_port,
      oci_image      => $oci_image,
      oci_tag        => $oci_tag,
      vm_name_prefix => $vm_name_prefix,
      worker_count   => $worker_count,
      insecure_flag  => $insecure_flag,
      bin_path       => $bin_path,
    }),
    require => Exec['install_tart'],
  }

  file { '/usr/local/bin/tart-update-vms.sh':
    ensure  => file,
    mode    => '0755',
    content => epp('roles_profiles/tart/tart-update-vms.sh.epp', {
      registry_host  => $registry_host,
      registry_port  => $registry_port,
      oci_image      => $oci_image,
      oci_tag        => $oci_tag,
      vm_name_prefix => $vm_name_prefix,
      worker_count   => $worker_count,
      insecure_flag  => $insecure_flag,
      bin_path       => $bin_path,
      user           => $user,
    }),
    require => Exec['install_tart'],
  }

  file { "/Users/${user}/Library/LaunchAgents":
    ensure => directory,
    owner  => $user,
    group  => 'staff',
    mode   => '0755',
  }

  exec { 'pull_initial_image':
    command => "su - ${user} -c '/usr/local/bin/tart-pull-image.sh'",
    path    => ['/usr/bin', '/bin', '/usr/local/bin'],
    require => [File['/usr/local/bin/tart-pull-image.sh']],
    timeout => 1800,
    unless  => "su - ${user} -c '${bin_path} list' | awk '{print \$1}' | grep -Fx '${vm_name_prefix}-1'",
  }

  Integer[1, $worker_count].each |$i| {
    $vm_name = "${vm_name_prefix}-${i}"

    file { "/Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist":
      ensure  => file,
      content => epp('roles_profiles/tart/com.mozilla.tartworker.plist.epp', {
        worker_id => $i,
        vm_name   => $vm_name,
        bin_path  => $bin_path,
        user      => $user,
      }),
      owner   => $user,
      group   => 'staff',
      mode    => '0644',
      require => [Exec['pull_initial_image'], File["/Users/${user}/Library/LaunchAgents"]],
      notify  => Exec["load_tartworker_${i}"],
    }

    exec { "load_tartworker_${i}":
      command     => "su - ${user} -c 'launchctl unload /Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist 2>/dev/null || true; launchctl load /Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist'",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      require     => File["/Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist"],
    }
  }
}
