# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Generates a CycloneDX 1.6 SBOM describing what is actually installed on a
# macOS CI worker, so the fleet's software inventory can be collected and
# scanned rather than inferred from these manifests.
#
# Writes to $sbom_dir:
#   sbom.cdx.json    full CycloneDX document, rewritten only on drift
#   fingerprint.json small summary including a stable sbom_sha256
#
# Both are world-readable so a collector can scrape them over SSH as a
# non-root user.
class macos_sbom (
  Boolean   $enabled         = true,
  String[1] $sbom_dir        = '/var/sbom',
  Integer   $refresh_minutes = 1440,
) {
  $script_path  = '/usr/local/bin/generate_sbom.py'
  $wrapper_path = '/usr/local/bin/run_sbom.sh'
  $fingerprint  = "${sbom_dir}/fingerprint.json"

  if $enabled {
    file { $sbom_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    file { $script_path:
      ensure => file,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
      source => 'puppet:///modules/macos_sbom/generate_sbom.py',
    }

    file { $wrapper_path:
      ensure => file,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
      source => 'puppet:///modules/macos_sbom/run_sbom.sh',
    }

    # A new generator can collect things the old one missed, so whatever is
    # on disk is stale by definition. Dropping the fingerprint defeats the
    # freshness check below and forces a regeneration this run.
    exec { 'invalidate_sbom_fingerprint':
      command     => "/bin/rm -f ${fingerprint}",
      refreshonly => true,
      subscribe   => [File[$script_path], File[$wrapper_path]],
      before      => Exec['generate_sbom'],
    }

    # Regenerate at most once per $refresh_minutes. Hashing /usr/local/bin on
    # every Puppet run would be wasted work on a fleet that only changes when
    # Puppet changes it, and would report a resource change on every run.
    exec { 'generate_sbom':
      command   => $wrapper_path,
      provider  => shell,
      unless    => "/usr/bin/find ${fingerprint} -mmin -${refresh_minutes} 2>/dev/null | /usr/bin/grep -q .",
      path      => ['/usr/local/bin', '/usr/bin', '/bin', '/usr/sbin', '/sbin'],
      timeout   => 900,
      logoutput => on_failure,
      require   => [File[$sbom_dir], File[$script_path], File[$wrapper_path]],
    }
  } else {
    file { [$script_path, $wrapper_path]:
      ensure => absent,
    }
  }
}
