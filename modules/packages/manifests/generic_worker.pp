# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::generic_worker (
    Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
    Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
    Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
) {

    packages::macos_package_from_github { '/usr/local/bin/generic-worker-darwin-amd64':
        github_repo_slug => 'taskcluster/generic-worker',
        version          => $generic_worker_version,
        filename         => 'generic-worker-darwin-amd64',
        type             => 'bin',
    }

    packages::macos_package_from_github { '/usr/local/bin/taskcluster-proxy-darwin-amd64':
        github_repo_slug => 'taskcluster/taskcluster-proxy',
        version          => $taskcluster_proxy_version,
        filename         => 'taskcluster-proxy-darwin-amd64',
        type             => 'bin',
    }

    packages::macos_package_from_github { '/usr/local/bin/quarantine-worker-darwin-amd64':
        github_repo_slug => 'mozilla-platform-ops/quarantine-worker',
        version          => $quarantine_worker_version,
        filename         => 'quarantine-worker-darwin-amd64',
        type             => 'bin',
    }
}
