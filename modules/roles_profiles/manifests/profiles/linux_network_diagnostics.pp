# Optional persistent network snapshots for unreachable-worker investigations.
class roles_profiles::profiles::linux_network_diagnostics {
  $requested = lookup('linux_network_diagnostics_enabled', Boolean, 'first', false)
  $hosts = lookup('linux_network_diagnostics_hosts', Array[String], 'first', [])
  $enabled = $requested and $facts['networking']['hostname'] in $hosts and
    $facts['os']['name'] == 'Ubuntu' and $facts['os']['release']['full'] == '18.04'

  class { 'linux_network_diagnostics':
    enabled => $enabled,
  }
}
