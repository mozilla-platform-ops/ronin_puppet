# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# TODO:
# - apache proxy setup?

class linux_generic_worker (
    String $taskcluster_client_id,
    String $taskcluster_access_token,
    String $livelog_secret,
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
    Pattern[/^v\d+\.\d+\.\d+$/] $livelog_version,
    String                      $livelog_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $start_worker_version,
    String                      $start_worker_sha256,
    Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
    String $quarantine_worker_sha256,
    String $taskcluster_host = 'taskcluster',
) {

    # include httpd
    include shared

    class { 'packages::linux_generic_worker':
        generic_worker_version    => $generic_worker_version,
        generic_worker_sha256     => $generic_worker_sha256,
        taskcluster_proxy_version => $taskcluster_proxy_version,
        taskcluster_proxy_sha256  => $taskcluster_proxy_sha256,
        livelog_version           => $livelog_version,
        livelog_sha256            => $livelog_sha256,
        start_worker_version      => $start_worker_version,
        start_worker_sha256       => $start_worker_sha256,
        quarantine_worker_version => $quarantine_worker_version,
        quarantine_worker_sha256  => $quarantine_worker_sha256
    }

    class { 'linux_generic_worker::control_bug':
        user_homedir     => $user_homedir,
        bugzilla_api_key => $bugzilla_api_key,
    }

    $livelog_certificate = "${user_homedir}/livelog.crt"
    $livelog_key         = "${user_homedir}/livelog.key"
    $task_dir            = "${user_homedir}/tasks"
    $caches_dir          = "${user_homedir}/caches"
    $downloads_dir       = "${user_homedir}/downloads"
    $ed25519_signing_key = "${user_homedir}/generic-worker.ed25519.signing.key"

    exec {
        'create ed25519 signing key':
            path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
            user    => $user,
            cwd     => $user_homedir,
            command => "generic-worker new-ed25519-keypair --file ${ed25519_signing_key}",
            unless  => "test -f ${ed25519_signing_key}",
            require => Class['packages::linux_generic_worker'];
    }

    # According to bug 1501936, https://bugzilla.mozilla.org/show_bug.cgi?id=1501936,Linux machines stuck at reboot process.
    # Looking over the internet, I found this bug: https://lists.ubuntu.com/archives/foundations-bugs/2016-April/280724.html
    # They suspet systemd generate this behavior. I reproduced this by genereting a reboot cron job
    # and run it every 10 minutes.
    # After around 24 hours the worker stuck at reboot process. I tryed to update systemd to the last version,
    # but without success. To fix this, I plan to add --force option to reboot command,
    # to shutdown without contacting the system manager.
    # According reboot man page:
    # -f, --force - Force immediate halt, power-off, or reboot. When specified once,
    # this results in an immediate but clean shutdown by the system manager. When specified twice,
    # this results in an immediate shutdown without contacting the system manager.
    # See the description of --force in systemctl(1) for more details.
    #
    # used in run-generic-woker file below
    $reboot_command = '/usr/bin/sudo /sbin/reboot --force'

    file {
        default:
            owner => $user,
            # TODO: take this as an arg, don't assume
            group => $user;

        ["${user_homedir}/.config",
        "${user_homedir}/.config/autostart"]:
            ensure => directory;
        "${user_homedir}/.config/autostart/gnome-terminal.desktop":
            content => template('linux_generic_worker/gnome-terminal.desktop.erb');

        ["${user_homedir}/tasks", "${user_homedir}/downloads"]:
            ensure => directory;

        '/usr/local/bin/run-start-worker.sh':
            ensure  => present,
            content => template('linux_generic_worker/run-start-worker.sh.erb'),
            owner   => root,
            group   => root,
            mode    => '0755';

        '/usr/local/bin/run-start-worker-wrapper.sh':
            ensure  => present,
            content => 'linux_generic_worker/run-start-worker-wrapper.sh',
            owner   => root,
            group   => root,
            mode    => '0755';

        '/etc/start-worker.yml':
            ensure  => present,
            content => template('linux_generic_worker/worker-runner-config.yml.erb'),
            owner   => root,
            group   => root,
            mode    => '0644';

        '/var/log/genericworker':
            ensure => directory,
            mode   => '0777';
    }

    # TODO: cleanup
    # from build-puppet, seems not needed for modern talos/raptor

    #         host { $taskcluster_host:
    #             ip => '127.0.0.1'
    #         }

    #         httpd::config { 'proxy.conf':
    #             content => template('generic_worker/proxy-httpd.conf.erb'),
    #         }

}
