# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging (
    String $worker_type         = '',  # not used by windows
    String $stackdriver_project = 'none',
    String $syslog_host         = join([
      'log-aggregator',
      "${1 + fqdn_rand(2)}",
      '.srv.releng.',
      regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1'),
      '.mozilla.com'
    ]),
    Integer $syslog_port        = 514,
    String $mac_log_level       = 'default',
) {

    # use a single write-only service account for each project
    $stackdriver_keyid    = lookup("stackdriver.${stackdriver_project}.keyid", {'default_value' => ''})
    $stackdriver_key      = lookup("stackdriver.${stackdriver_project}.key", {'default_value' => ''})
    $stackdriver_clientid = lookup("stackdriver.${stackdriver_project}.clientid", {'default_value' => ''})

    case $::operatingsystem {
        'Windows': {

            if ($facts['custom_win_location'] == 'datacenter') {
                $log_aggregator  = lookup('windows.datacenter.log_aggregator')
                $conf_file = 'nxlog.conf'
            } elsif ($facts['custom_win_location']) == 'azure' {
                $log_aggregator  = lookup('windows.external.papertrail')
                $conf_file = 'azure_nxlog.conf.epp'
            } else {
                # data will need to be added as could support builds out
                $log_aggregator  = lookup('windows.external.papertrail')
                $conf_file = 'non_datacenter_nxlog.conf'
            }

            class { 'win_nxlog':
                nxlog_dir      => "${facts['custom_win_programfilesx86']}\\nxlog",
                location       => $facts['custom_win_location'],
                node_name      => $facts['networking']['fqdn'],
                log_aggregator => $log_aggregator,
                conf_file      => $conf_file,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
        }
        'Darwin': {
            class { 'fluentd':
                worker_type          => $worker_type,
                stackdriver_project  => $stackdriver_project,
                stackdriver_keyid    => $stackdriver_keyid,
                stackdriver_key      => $stackdriver_key,
                stackdriver_clientid => $stackdriver_clientid,
                syslog_host          => $syslog_host,
                syslog_port          => $syslog_port,
                mac_log_level        => $mac_log_level,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
