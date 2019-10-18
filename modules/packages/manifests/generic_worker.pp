# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::generic_worker (
    Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
    String                      $generic_worker_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
    String                      $taskcluster_proxy_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
    String                      $quarantine_worker_sha256,
    Optional[Pattern[/^v\d+\.\d+\.\d+$/]] $livelog_version = undef,
    Optional[String]                      $livelog_sha256  = undef,
) {

    packages::macos_package_from_s3 { "generic-worker-darwin-amd64-${generic_worker_version}":
        private             => false,
        os_version_specific => true,
        type                => 'bin',
        file_destination    => '/usr/local/bin/generic-worker',
        checksum            => $generic_worker_sha256,
    }

    packages::macos_package_from_s3 { "taskcluster-proxy-darwin-amd64-${taskcluster_proxy_version}":
        private             => false,
        os_version_specific => true,
        type                => 'bin',
        file_destination    => '/usr/local/bin/taskcluster-proxy',
        checksum            => $taskcluster_proxy_sha256,
    }

    packages::macos_package_from_s3 { "quarantine-worker-darwin-amd64-${quarantine_worker_version}":
        private             => false,
        os_version_specific => true,
        type                => 'bin',
        file_destination    => '/usr/local/bin/quarantine-worker',
        checksum            => $quarantine_worker_sha256,
    }

    if $livelog_version != undef {
        packages::macos_package_from_s3 { "livelog-darwin-amd64-${livelog_version}":
            private             => false,
            os_version_specific => true,
            type                => 'bin',
            file_destination    => '/usr/local/bin/livelog',
            checksum            => $livelog_sha256,
        }
    }
}
