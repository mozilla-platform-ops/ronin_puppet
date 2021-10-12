# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class worker_runner (
    Pattern[/^\d+\.\d+\.\d+$/] $taskcluster_version,
    Enum['aws', 'azure', 'google', 'standalone', 'static'] $provider_type,
    String $root_url,
    String $data_dir                                   = '/opt/worker',
    String $task_user                                  = 'cltbld',
    Enum['simple', 'multiuser'] $generic_worker_engine = 'multiuser',
    String $taskcluster_proxy_host                     = 'taskcluster',
    # used by standalone
    Optional[String] $client_id                        = undef,
    Optional[String] $access_token                     = undef,
    # used by static
    Optional[String] $provider_id                      = undef,
    Optional[String] $static_secret                    = undef,
    # used by both standalone and static
    Optional[String] $worker_pool_id                   = undef,
    Optional[String] $worker_group                     = undef,
    Optional[String] $worker_id                        = undef,
    Optional[Hash] $provider_metadata                  = undef,
    Optional[Hash] $worker_location                    = undef,
    Optional[Integer] $idle_timeout_secs               = undef,
    # TODO: implement more worker config parameters
    # WorkerConfig parameters
    # Optional[String] $availabilityZone                 = undef,
    # Optional[String] $cachesDir                        = undef,
    # Optional[String] $certificate                      = undef,
    # Optional[String] $checkForNewDeploymentEverySecs   = undef,
    # Optional[String] $cleanUpTaskDirs                  = undef,
    # Optional[String] $deploymentId                     = undef,
    # Optional[String] $disableReboots                   = undef,
    # Optional[String] $downloadsDir                     = undef,
    # Optional[String] $instanceID                       = undef,
    # Optional[String] $instanceType                     = undef,
    # Optional[String] $livelogExecutable                = undef,
    # Optional[String] $numberOfTasksToRun               = undef,
    # Optional[String] $privateIP                        = undef,
    # Optional[String] $provisionerId                    = undef,
    # Optional[String] $publicIP                         = undef,
    # Optional[String] $region                           = undef,
    # Optional[String] $requiredDiskSpaceMegabytes       = undef,
    # Optional[String] $runAfterUserCreation             = undef,
    # Optional[String] $runTasksAsCurrentUser            = undef,
    # Optional[String] $sentryProject                    = undef,
    # Optional[String] $shutdownMachineOnIdle            = undef,
    # Optional[String] $shutdownMachineOnInternalError   = undef,
    # Optional[String] $taskclusterProxyExecutable       = undef,
    # Optional[String] $taskclusterProxyPort             = undef,
    # Optional[String] $tasksDir                         = undef,
    # Optional[String] $workerGroup                      = undef,
    # Optional[Hash]   $workerTypeMetaData               = undef,
    # Optional[String] $wstAudience                      = undef,
    # Optional[String] $wstServerURL                     = undef,
) {

    if $provider_type == 'standalone' {
        if ! $client_id or ! $access_token {
            fail("[${module_name}] provider type standalone requires client_id and access_token")
        }
    }
    if $provider_type == 'static' {
        if ! $provider_id or ! $static_secret {
            fail("[${module_name}] provider type static requires provider id and static_secret")
        }
    }
    if $provider_type == 'standalone' or $provider_type == 'static'{
        if ! $worker_pool_id or ! $worker_group or ! $worker_id {
            fail("[${module_name}] provider type standalone or static require worker_pool_id, worker_group, and worker_id")
        }
    }

    $task_dir                = "${data_dir}/tasks"
    $cache_dir               = "${data_dir}/cache"
    $downloads_dir           = "${data_dir}/downloads"
    $log_dir                 = "${data_dir}/logs"
    $worker_runner_conf      = "${data_dir}/worker-runner-config.yaml"
    $ed25519_signing_key     = "${data_dir}/generic-worker.ed25519.signing.key"

    case $::operatingsystem {
        'Darwin': {

            if $generic_worker_engine == 'multiuser' {
                $owner        = 'root'
                $group        = 'wheel'
                $launch_plist = '/Library/LaunchDaemons/org.mozilla.worker-runner.plist'
            } else {
                $owner        = $task_user
                $group        = 'staff'
                $launch_plist = "/Users/${task_user}/Library/LaunchAgents/org.mozilla.worker-runner.plist"
            }

            # arm64 if Apple processor
            if /^Apple.*/ in $facts['processors']['models'] {
                $arch_name = 'arm64'
            } else {
                $arch_name = 'amd64'
            }

            $taskcluster_binaries = [ 'start-worker', 'generic-worker-multiuser', 'generic-worker-simple', 'livelog', 'taskcluster-proxy' ]
            $taskcluster_binaries.each |String $bin| {
                $pkg_name = "${bin}-${taskcluster_version}-${arch_name}"
                packages::macos_package_from_s3 { $pkg_name:
                    private             => false,
                    os_version_specific => false,
                    type                => 'bin',
                    file_destination    => "/usr/local/bin/${bin}",
                }
            }

            # Create worker data dir
            file { $data_dir:
                ensure => 'directory',
                owner  => $owner,
                group  => $group,
            }

            # Create tasks, caches, downloads and log dirs

            file { [ $log_dir ]:
                ensure => 'directory',
                mode   => '0700',
                owner  => $owner,
                group  => $group,
            }

            file { [ $task_dir, $cache_dir, $downloads_dir ]:
                ensure => 'directory',
                mode   => '1777',
                owner  => $owner,
                group  => $group,
            }

            # Generate an ed25519 key
            exec { 'create ed25519 signing key':
                cwd     => $data_dir,
                command => "/usr/local/bin/generic-worker-${generic_worker_engine} new-ed25519-keypair --file ${ed25519_signing_key}",
                unless  => "/bin/test -f ${ed25519_signing_key}",
            }

            # Set permissions on ed25519 key
            file { $ed25519_signing_key:
                ensure    => present,
                mode      => '0600',
                show_diff => false,
                owner     => $owner,
                group     => $group,
            }

            # TODO: Don't assume worker config variables.  Do better at validating and inject them as needed into the worker config
            # Worker runner config
            file { $worker_runner_conf:
                ensure  => file,
                content => template("${module_name}/worker_runner_config.yaml.erb"),
                mode    => '0600',
                owner   => $owner,
                group   => $group,
            }

            # Worker runner launchd plist
            # This launchd plist works for both multiuser (LaunchDaemon) and simple (LaunchAgent)
            file { $launch_plist:
                ensure  => present,
                content => template("${module_name}/org.mozilla.worker-runner.plist.erb"),
                mode    => '0644',
                owner   => $owner,
                group   => $group,
            }

            # Worker runner wrapper script
            file { '/usr/local/bin/worker-runner.sh':
                ensure  => present,
                content => template("${module_name}/worker-runner.sh.erb"),
                mode    => '0755',
            }

            # Add taskcluster host entry
            host { 'taskcluster':
                ip => '127.0.0.1'
            }

            httpd::config { 'proxy.conf':
                content => template("${module_name}/proxy-httpd.conf.erb"),
            }
        }
        default: {
            fail("${module_name} is not supported on ${::operatingsystem}")
        }
    }

}
