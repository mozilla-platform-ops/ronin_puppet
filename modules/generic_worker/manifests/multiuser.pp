# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class generic_worker::multiuser (
    String $taskcluster_client_id,
    String $taskcluster_access_token,
    String $worker_group,
    String $worker_type,
    String $user,
    #String $gw_dir   = '/etc/generic-worker',
    String $data_dir = '/var/opt/generic-worker',
    Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
    String $generic_worker_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
    String $taskcluster_proxy_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $livelog_version,
    String $livelog_sha256,
    String $taskcluster_host = 'taskcluster',
) {

    include httpd

    class { 'packages::generic_worker':
        generic_worker_version    => $generic_worker_version,
        generic_worker_sha256     => $generic_worker_sha256,
        taskcluster_proxy_version => $taskcluster_proxy_version,
        taskcluster_proxy_sha256  => $taskcluster_proxy_sha256,
        livelog_version           => $livelog_version,
        livelog_sha256            => $livelog_sha256
    }

    $task_dir            = "${data_dir}/tasks"
    $caches_dir          = "${data_dir}/caches"
    $downloads_dir       = "${data_dir}/downloads"
    $ed25519_signing_key = '/etc/generic-worker/generic-worker.ed25519.signing.key'

    exec {
        'create ed25519 signing key':
            path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
            user    => $user,
            cwd     => '/etc/generic-worker',
            command => "generic-worker new-ed25519-keypair --file ${ed25519_signing_key}",
            unless  => "test -f ${ed25519_signing_key}",
            require => Class['packages::generic_worker'];
    }
    file {
        'ed25519_signing_key_permissions':
            ensure    => present,
            mode      => '0600',
            owner     => $user,
            show_diff => false,
            path      => $ed25519_signing_key;
    }

    case $::operatingsystem {
        'Darwin': {

            $reboot_command = '/usr/bin/sudo /sbin/reboot'

            file {

                # Ensure old plist and config files doesn’t exists, and deletes them, if necessary.
                '/Library/LaunchAgents/net.generic.worker.plist':
                    ensure  => absent;
                '/etc/generic-worker.config':
                    ensure  => absent;

                '/Library/LaunchDaemons/com.mozilla.genericworker.plist':
                    ensure  => present,
                    content => template('generic_worker/generic-worker.plist.multiuser.erb'),
                    mode    => '0644',
                    owner   => $::root_user,
                    group   => $::root_group;

                '/usr/local/bin/run-generic-worker.sh':
                    ensure  => present,
                    content => template('generic_worker/run-generic-worker.sh.multiuser.erb'),
                    mode    => '0755',
                    owner   => $::root_user,
                    group   => $::root_group;

                '/etc/generic-worker':
                    ensure => directory,
                    mode   => '0600',
                    owner  => $::root_user,
                    group  => $::root_group;

                '/etc/generic-worker/config':
                    ensure  => present,
                    content => template('generic_worker/generic-worker.config.multiuser.erb'),
                    mode    => '0600',
                    owner   => $::root_user,
                    group   => $::root_group,
                    #show_diff => false,
                    require => File['/etc/generic-worker'];

                #'/etc/generic-worker/runner.yml':
                #    ensure  => present,
                #    content => template('generic_worker/generic-worker.multiuser.yml.erb'),
                #    mode    => '0600',
                #    owner   => $::root_user,
                #    group   => $::root_group,
                #    #show_diff => false,
                #    require => File['/etc/generic-worker'];

                '/var/log/generic-worker':
                    ensure => directory,
                    mode   => '0777',
                    owner  => $::root_user,
                    group  => $::root_group;

                '/var/opt/generic-worker':
                    ensure => directory,
                    mode   => '0777',
                    owner  => $user,
                    group  => $::root_group,
                    path   => $data_path;

                #'/var/local':
                #    ensure => directory,
                #    mode   => '0644',
                #    owner  => $::root_user,
                #    group  => $::root_group;

                #$gw_dir:
                #    ensure => directory,
                #    mode   => '0600',
                #    owner  => $::root_user,
                #    group  => $::root_group;
            }

            service { 'com.mozilla.genericworker':
                require => File['/Library/LaunchDaemons/con.mozilla.genericworker.plist'],
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
