# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::generic_worker (
    Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
    # String                      $generic_worker_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
    # String                      $taskcluster_proxy_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
    # String                      $quarantine_worker_sha256,
) {

    packages::linux_package_from_github { "generic-worker-linux-x386-${generic_worker_version}":
      'taskcluster/generic-worker',
      '16.6.1',
      'generic-worker-simple-linux-368',
      file_destination    => '/usr/local/bin/generic-worker',
    }

    packages::linux_package_from_github { "taskcluster-proxy-linux-amd64-${taskcluster_proxy_version}":
      'taskcluster/taskcluster-proxy',
      '5.1.0',
      'taskcluster-proxy-linux-amd64',
      file_destination    => '/usr/local/bin/taskcluster-proxy',
    }

    packages::linux_package_from_github { "quarantine-worker-linux-amd64-${quarantine_worker_version}":
      'mozilla-platform-ops/quarantine-worker',
      'v1.0.0',
      'quarantine-worker-linux-amd64',
      file_destination    => '/usr/local/bin/quarantine-worker',
    }

    # TODO: move to installation from s3

    # packages::linux_package_from_s3 { "generic-worker-linux-x386-${generic_worker_version}":
    #     private             => false,
    #     os_version_specific => true,
    #     type                => 'bin',
    #     file_destination    => '/usr/local/bin/generic-worker',
    #     checksum            => $generic_worker_sha256,
    # }

    # packages::linux_package_from_s3 { "taskcluster-proxy-darwin-amd64-${taskcluster_proxy_version}":
    #     private             => false,
    #     os_version_specific => true,
    #     type                => 'bin',
    #     file_destination    => '/usr/local/bin/taskcluster-proxy',
    #     checksum            => $taskcluster_proxy_sha256,
    # }

    # packages::linux_package_from_s3 { "quarantine-worker-darwin-amd64-${quarantine_worker_version}":
    #     private             => false,
    #     os_version_specific => true,
    #     type                => 'bin',
    #     file_destination    => '/usr/local/bin/quarantine-worker',
    #     checksum            => $quarantine_worker_sha256,
    # }
}
