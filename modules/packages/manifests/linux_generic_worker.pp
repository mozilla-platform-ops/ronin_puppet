# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# TODO: move this to linux_packages::generic_worker
class packages::linux_generic_worker (
  Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
  Variant[String, Hash[String, String]] $generic_worker_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
  Variant[String, Hash[String, String]] $taskcluster_proxy_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $livelog_version,
  Variant[String, Hash[String, String]] $livelog_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $start_worker_version,
  Variant[String, Hash[String, String]] $start_worker_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
  String                      $quarantine_worker_sha256,
  Enum['s3', 'github']        $taskcluster_binary_source = 's3',
) {
  $threshold_version = '63.0.0'
  $gw_version_without_v = regsubst($generic_worker_version, 'v', '')
  $taskcluster_arch = $facts['os']['architecture'] ? {
    'amd64'   => 'amd64',
    'x86_64'  => 'amd64',
    'arm64'   => 'arm64',
    'aarch64' => 'arm64',
    default   => fail("Unsupported Taskcluster Linux architecture ${facts['os']['architecture']}"),
  }

  if $generic_worker_sha256 =~ Hash {
    $generic_worker_checksum = $generic_worker_sha256[$taskcluster_arch] ? {
      undef   => fail("No generic-worker checksum for ${taskcluster_arch}"),
      default => $generic_worker_sha256[$taskcluster_arch],
    }
  } else {
    $generic_worker_checksum = $generic_worker_sha256
  }
  if $taskcluster_proxy_sha256 =~ Hash {
    $taskcluster_proxy_checksum = $taskcluster_proxy_sha256[$taskcluster_arch] ? {
      undef   => fail("No taskcluster-proxy checksum for ${taskcluster_arch}"),
      default => $taskcluster_proxy_sha256[$taskcluster_arch],
    }
  } else {
    $taskcluster_proxy_checksum = $taskcluster_proxy_sha256
  }
  if $livelog_sha256 =~ Hash {
    $livelog_checksum = $livelog_sha256[$taskcluster_arch] ? {
      undef   => fail("No livelog checksum for ${taskcluster_arch}"),
      default => $livelog_sha256[$taskcluster_arch],
    }
  } else {
    $livelog_checksum = $livelog_sha256
  }
  if $start_worker_sha256 =~ Hash {
    $start_worker_checksum = $start_worker_sha256[$taskcluster_arch] ? {
      undef   => fail("No start-worker checksum for ${taskcluster_arch}"),
      default => $start_worker_sha256[$taskcluster_arch],
    }
  } else {
    $start_worker_checksum = $start_worker_sha256
  }

  if versioncmp($gw_version_without_v, $threshold_version) < 0 {
    $generic_worker_asset = 'generic-worker-simple'
    notice('g-w: using simple g-w')
  } else {
    $generic_worker_asset = 'generic-worker-insecure'
    notice('g-w: using insecure g-w')
  }

  if $taskcluster_binary_source == 'github' {
    packages::linux_taskcluster_binary { 'generic-worker':
      version          => $generic_worker_version,
      asset_name       => $generic_worker_asset,
      file_destination => '/usr/local/bin/generic-worker',
      sha256           => $generic_worker_checksum,
    }

    packages::linux_taskcluster_binary { 'taskcluster-proxy':
      version          => $taskcluster_proxy_version,
      file_destination => '/usr/local/bin/taskcluster-proxy',
      sha256           => $taskcluster_proxy_checksum,
    }

    packages::linux_taskcluster_binary { 'livelog':
      version          => $livelog_version,
      file_destination => '/usr/local/bin/livelog',
      sha256           => $livelog_checksum,
    }

    packages::linux_taskcluster_binary { 'start-worker':
      version          => $start_worker_version,
      file_destination => '/usr/local/bin/start-worker',
      sha256           => $start_worker_checksum,
    }
  } else {
    packages::linux_package_from_s3 { "${generic_worker_asset}-linux-amd64-${generic_worker_version}":
      private             => false,
      os_version_specific => false,
      type                => 'bin',
      file_destination    => '/usr/local/bin/generic-worker',
      checksum            => $generic_worker_checksum,
    }

    packages::linux_package_from_s3 { "taskcluster-proxy-linux-amd64-${taskcluster_proxy_version}":
      private             => false,
      os_version_specific => false,
      type                => 'bin',
      file_destination    => '/usr/local/bin/taskcluster-proxy',
      checksum            => $taskcluster_proxy_checksum,
    }

    packages::linux_package_from_s3 { "livelog-linux-amd64-${livelog_version}":
      private             => false,
      os_version_specific => false,
      type                => 'bin',
      file_destination    => '/usr/local/bin/livelog',
      checksum            => $livelog_checksum,
    }

    packages::linux_package_from_s3 { "start-worker-linux-amd64-${start_worker_version}":
      private             => false,
      os_version_specific => false,
      type                => 'bin',
      file_destination    => '/usr/local/bin/start-worker',
      checksum            => $start_worker_checksum,
    }
  }

  packages::linux_package_from_s3 { "quarantine-worker-linux-amd64-${quarantine_worker_version}":
    private             => false,
    os_version_specific => false,
    type                => 'bin',
    file_destination    => '/usr/local/bin/quarantine-worker',
    checksum            => $quarantine_worker_sha256,
  }
}
