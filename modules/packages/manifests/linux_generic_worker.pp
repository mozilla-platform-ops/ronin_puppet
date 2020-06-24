# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::linux_generic_worker (
    Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
    String                      $generic_worker_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
    String                      $taskcluster_proxy_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
    String                      $quarantine_worker_sha256,
) {

    packages::linux_package_from_s3 { "generic-worker-simple-linux-386-${generic_worker_version}":
        private             => false,
        os_version_specific => false,
        type                => 'bin',
        file_destination    => '/usr/local/bin/generic-worker',
        checksum            => $generic_worker_sha256,
    }

    packages::linux_package_from_s3 { "taskcluster-proxy-linux-amd64-${taskcluster_proxy_version}":
        private             => false,
        os_version_specific => false,
        type                => 'bin',
        file_destination    => '/usr/local/bin/taskcluster-proxy',
        checksum            => $taskcluster_proxy_sha256,
    }

    packages::linux_package_from_s3 { "quarantine-worker-linux-amd64-${quarantine_worker_version}":
        private             => false,
        os_version_specific => false,
        type                => 'bin',
        file_destination    => '/usr/local/bin/quarantine-worker',
        checksum            => $quarantine_worker_sha256,
    }
}
