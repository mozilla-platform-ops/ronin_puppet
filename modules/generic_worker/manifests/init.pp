# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class generic_worker (
    String $taskcluster_client_id,
    String $taskcluster_access_token,
    Optional[String] $livelog_secret = undef,
    String $worker_group,
    String $worker_type,
    String $quarantine_client_id,
    String $quarantine_access_token,
    String $bugzilla_api_key,
    String $user,
    String $user_homedir,
    Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
    String $generic_worker_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
    String $taskcluster_proxy_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
    String $quarantine_worker_sha256,
    String $taskcluster_host = 'taskcluster',
) {

    include httpd
    include shared

    class { 'packages::generic_worker':
        generic_worker_version    => $generic_worker_version,
        generic_worker_sha256     => $generic_worker_sha256,
        taskcluster_proxy_version => $taskcluster_proxy_version,
        taskcluster_proxy_sha256  => $taskcluster_proxy_sha256,
        quarantine_worker_version => $quarantine_worker_version,
        quarantine_worker_sha256  => $quarantine_worker_sha256
    }

    class { 'generic_worker::control_bug':
        user_homedir     => $user_homedir,
        bugzilla_api_key => $bugzilla_api_key,
    }

    $livelog_certificate = "${user_homedir}/livelog.crt"
    $livelog_key         = "${user_homedir}/livelog.key"
    $task_dir            = "${user_homedir}/tasks"
    $caches_dir          = "${user_homedir}/caches"
    $downloads_dir       = "${user_homedir}/downloads"
    $opengpg_signing_key = "${user_homedir}/generic-worker.openpgp.signing.key"
    $ed25519_signing_key = "${user_homedir}/generic-worker.ed25519.signing.key"

    exec {
        'create opengpg signing key':
            path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
            user    => $user,
            cwd     => $user_homedir,
            command => "generic-worker new-openpgp-keypair --file ${opengpg_signing_key}",
            unless  => "test -f ${opengpg_signing_key}",
            require => Class['packages::generic_worker'];

        'create ed25519 signing key':
            path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
            user    => $user,
            cwd     => $user_homedir,
            command => "generic-worker new-ed25519-keypair --file ${ed25519_signing_key}",
            unless  => "test -f ${ed25519_signing_key}",
            require => Class['packages::generic_worker'];
    }

    case $::operatingsystem {
        'Darwin': {

            $reboot_command = '/usr/bin/sudo /sbin/reboot'

            file {
                default: * => $::shared::file_defaults;

                '/Library/LaunchAgents/net.generic.worker.plist':
                    ensure  => present,
                    content => template('generic_worker/generic-worker.plist.erb'),
                    mode    => '0644';

                '/usr/local/bin/run-generic-worker.sh':
                    ensure  => present,
                    content => template('generic_worker/run-generic-worker.sh.erb'),
                    mode    => '0755';

                '/etc/generic-worker.config':
                    ensure  => present,
                    content => template('generic_worker/generic-worker.config.erb'),
                    mode    => '0644';
            }

            service { 'net.generic.worker':
                require => File['/Library/LaunchAgents/net.generic.worker.plist'],
                enable  => true,
            }

            host { $taskcluster_host:
                ip => '127.0.0.1'
            }

            httpd::config { 'proxy.conf':
                content => template('generic_worker/proxy-httpd.conf.erb'),
            }
        }
        default: {
            fail("${module_name} is not supported on ${::operatingsystem}")
        }
    }
}
