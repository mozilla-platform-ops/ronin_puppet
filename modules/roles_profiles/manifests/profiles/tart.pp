# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs Tart and manages N worker VMs that start and stay running.
#
# Two axes of behaviour, both hiera-driven (defaults preserve the original
# gecko-1b builder-host behaviour):
#
#   tart.manage_image (Boolean, default true)
#     true  - puppet pulls the OCI image and clones the VMs.
#     false - puppet does NOT pull/clone. Required on macOS 15+, where
#             `tart pull` only succeeds from the logged-in console GUI session
#             (Local Network privacy denies the registry connection from a
#             headless puppet/ssh context, surfacing as "The Internet
#             connection appears to be offline"). On those hosts the image is
#             seeded once by hand from the console and puppet only manages tart
#             itself + the launchd unit.
#
#   tart.launchd_type (Enum['agent','daemon'], default 'agent')
#     agent  - per-user LaunchAgent in ~/Library/LaunchAgents (gui domain;
#              only loads from a console session).
#     daemon - system LaunchDaemon in /Library/LaunchDaemons, runs `tart run`
#              as the configured user via UserName. Loads headlessly with
#              `launchctl bootstrap system` and starts at boot, so the VMs
#              survive reboots without a console session. When switching a host
#              from agent to daemon, any previously-loaded gui-domain agent is
#              evicted and its plist removed first, so the two don't race to
#              `tart run` the same VM.
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
  $manage_image   = lookup('tart.manage_image',   Boolean, 'first', true)
  $launchd_type   = lookup('tart.launchd_type',   Enum['agent', 'daemon'], 'first', 'agent')

  # Host-mediated worker-vault injection (tart.inject_vault, default false).
  # When true, the tartworker daemon runs tart-run-vm.sh, which fetches the
  # worker vault from the relops-bootstrap broker over mTLS using the host's
  # SCEP-issued System-keychain cert (role = tart.vault_role) and shares it into
  # the guest via `tart run --dir`; the guest's first-boot puppet run turns it
  # into the generic-worker config. Leave false until the credential-free image
  # (which reads the injected vault at boot) is deployed — with a baked image the
  # injected dir is simply ignored. Only meaningful when launchd_type == daemon.
  $inject_vault   = lookup('tart.inject_vault',   Boolean, 'first', false)
  $vault_role     = lookup('tart.vault_role',     String,  'first', '')
  $broker_host    = lookup('tart.broker_host',    String,  'first', 'forge.relops.mozilla.com')
  $scep_issuer_cn = lookup('tart.scep_issuer_cn', String,  'first', 'Mozilla RelOps Bootstrap CA Intermediate CA')
  $vault_dir_base = "/Users/${user}/.tart-vault"

  # Rolling image-update knobs (tart-update-vms.sh). tc_worker_pool is the TC
  # pool the VMs join (provisioner/worker-type); when set, the update drains each
  # slot's worker (waits for its current task to finish, via the TC *public* API
  # — no creds) before recreating it. Empty = no drain (mechanical recreate).
  $tc_root_url    = lookup('tart.tc_root_url',    String,  'first', 'https://firefox-ci-tc.services.mozilla.com')
  $tc_worker_pool = lookup('tart.tc_worker_pool', String,  'first', '')
  $drain_timeout  = lookup('tart.drain_timeout',  Integer, 'first', 3600)

  # Autologin the VM-host user. Apple's Virtualization Framework needs an active
  # GUI (Aqua) session for `tart run` to start a VM, and on a headless host that
  # session only exists via autologin at boot. Without a puppet-managed
  # /etc/kcpassword, a host can reboot to the login window with no session: the
  # launchd daemons load fine but every VM fails to start with "Internal
  # Virtualization error" (hit on macmini-m4-187, 2026-07-16 — its kcpassword
  # was missing while sibling hosts happened to have it). Managing it here makes
  # reboot-resilience guaranteed instead of dependent on original provisioning.
  #
  # tart_autologin_kcpassword = base64 of the admin user's /etc/kcpassword.
  # Populate it in vault/hiera; left empty it is a no-op (autologin unmanaged,
  # falls back to whatever the host was provisioned with).
  #
  # NB: TOP-LEVEL key, deliberately NOT nested under the `tart` hash. Secrets
  # live in vault.yaml (highest-priority hiera layer) and lookups here use
  # 'first' (no deep merge); a partial `tart: {autologin_kcpassword: ...}` in
  # vault.yaml would shadow the whole role-data `tart` hash (hiding version /
  # registry_host / oci_image / etc.). A distinct top-level key avoids that.
  $autologin_kcpassword = lookup('tart_autologin_kcpassword', String, 'first', '')
  if $autologin_kcpassword != '' {
    class { 'macos_utils::autologin_user':
      user       => $user,
      kcpassword => $autologin_kcpassword,
    }
  }

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
      launchd_type   => $launchd_type,
      tc_root_url    => $tc_root_url,
      tc_worker_pool => $tc_worker_pool,
      drain_timeout  => $drain_timeout,
    }),
    require => Exec['install_tart'],
  }

  # Pull the image + clone the VMs (only when puppet owns the image lifecycle).
  if $manage_image {
    exec { 'pull_initial_image':
      command => "su - ${user} -c '/usr/local/bin/tart-pull-image.sh'",
      path    => ['/usr/bin', '/bin', '/usr/local/bin'],
      require => File['/usr/local/bin/tart-pull-image.sh'],
      timeout => 1800,
      # tart list is columnar ("local <name> ..."); match the name field ($2),
      # not $1 (the literal "local"). The old $1 check never matched, so the
      # pull re-ran on every apply.
      unless  => "su - ${user} -c '${bin_path} list' | awk '\$1==\"local\"{print \$2}' | grep -Fx '${vm_name_prefix}-1'",
    }
    $image_require = [Exec['pull_initial_image']]
  } else {
    $image_require = []
  }

  if $launchd_type == 'agent' {
    file { "/Users/${user}/Library/LaunchAgents":
      ensure => directory,
      owner  => $user,
      group  => 'staff',
      mode   => '0755',
    }
    $dir_require = [File["/Users/${user}/Library/LaunchAgents"]]
  } else {
    $dir_require = []
  }

  # The daemon runs this wrapper instead of `tart run` directly, so it can inject
  # the worker vault into each VM at launch (see tart.inject_vault above). One
  # shared script; the plist passes the VM name. Only the daemon path uses it.
  if $launchd_type == 'daemon' {
    file { '/usr/local/bin/tart-run-vm.sh':
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0755',
      content => epp('roles_profiles/tart/tart-run-vm.sh.epp', {
        user           => $user,
        bin_path       => $bin_path,
        inject_vault   => $inject_vault,
        vault_role     => $vault_role,
        broker_host    => $broker_host,
        scep_issuer_cn => $scep_issuer_cn,
        vault_dir_base => $vault_dir_base,
      }),
      require => Exec['install_tart'],
    }
    $wrapper_require = [File['/usr/local/bin/tart-run-vm.sh']]
  } else {
    $wrapper_require = []
  }

  Integer[1, $worker_count].each |$i| {
    $vm_name = "${vm_name_prefix}-${i}"

    if $launchd_type == 'daemon' {
      $plist_path  = "/Library/LaunchDaemons/com.mozilla.tartworker-${i}.plist"
      $agent_plist = "/Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist"

      # Migrate a host off the old gui-domain LaunchAgent. While the agent is
      # loaded it holds the VM, so the daemon's `tart run` would lose the race
      # and KeepAlive-flap on "VM already running". Evict the loaded agent
      # (root can target the user's gui domain) and remove its plist so it
      # cannot reload at the next autologin/reboot. onlyif keeps it idempotent.
      exec { "evict_agent_tartworker_${i}":
        command => "/bin/bash -c 'launchctl bootout gui/\$(id -u ${user})/com.mozilla.tartworker-${i}'",
        path    => ['/bin', '/usr/bin'],
        onlyif  => "/bin/bash -c 'launchctl print gui/\$(id -u ${user})/com.mozilla.tartworker-${i} >/dev/null 2>&1'",
        notify  => Exec["load_tartworker_${i}"],
      }

      file { $agent_plist:
        ensure => absent,
      }

      file { $plist_path:
        ensure  => file,
        content => epp('roles_profiles/tart/com.mozilla.tartworker.daemon.plist.epp', {
          worker_id => $i,
          vm_name   => $vm_name,
          user      => $user,
        }),
        owner   => 'root',
        group   => 'wheel',
        mode    => '0644',
        require => $image_require + $dir_require + $wrapper_require + [Exec["evict_agent_tartworker_${i}"], File[$agent_plist]],
        notify  => Exec["load_tartworker_${i}"],
      }

      # system domain: loads headlessly, no console session required. Wrapped in
      # bash -c because the command uses shell operators (;, ||, redirection)
      # that Puppet's exec does not pass through a shell on its own.
      exec { "load_tartworker_${i}":
        command     => "/bin/bash -c 'launchctl bootout system ${plist_path} 2>/dev/null || true; launchctl bootstrap system ${plist_path}'",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        require     => File[$plist_path],
      }
    } else {
      $plist_path = "/Users/${user}/Library/LaunchAgents/com.mozilla.tartworker-${i}.plist"

      file { $plist_path:
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
        require => $image_require + $dir_require,
        notify  => Exec["load_tartworker_${i}"],
      }

      exec { "load_tartworker_${i}":
        command     => "su - ${user} -c 'launchctl unload ${plist_path} 2>/dev/null || true; launchctl load ${plist_path}'",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        require     => File[$plist_path],
      }
    }
  }
}
