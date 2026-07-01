# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs the fleetbench hardware-health benchmarking collector on Windows
# hardware nodes and deploys a wrapper script that runs it and saves the
# results to a known location. Wired in via the hardware_observability profile.
# See https://github.com/mozilla-platform-ops/fleetbench (RELOPS-2402).
class win_fleetbench::init (
  String $version,
  String $download_url,
  String $install_dir,
  String $results_dir,
) {
  $pkg       = "fleetbench-v${version}-windows-x86_64.exe"
  $url       = "${download_url}/v${version}/${pkg}"
  $binary    = "${install_dir}\\fleetbench-${version}.exe"
  $wrapper   = "${install_dir}\\run_fleetbench.ps1"
  $baselines = "${install_dir}\\fleetbench_baselines.json"

  file { $install_dir:
    ensure => directory,
  }

  # Known location where benchmark result envelopes are written.
  file { $results_dir:
    ensure  => directory,
    require => File[$install_dir],
  }

  # Pull the pinned collector binary from GitHub releases. The on-disk name is
  # version-stamped so a hiera version bump triggers a fresh download.
  archive { 'fleetbench-collector':
    ensure  => present,
    source  => $url,
    path    => $binary,
    creates => $binary,
    cleanup => false,
    extract => false,
    require => File[$install_dir],
  }

  # Wrapper that invokes the collector and writes results to $results_dir.
  file { $wrapper:
    ensure  => file,
    content => file('win_fleetbench/run_fleetbench.ps1'),
    require => File[$install_dir],
  }

  # Known-good per-hardware-type baselines, co-located with the collector. The
  # maintain-system fleetbench check reads this for its good/bad determination.
  file { $baselines:
    ensure  => file,
    content => file('win_fleetbench/fleetbench_baselines.json'),
    require => File[$install_dir],
  }
}
