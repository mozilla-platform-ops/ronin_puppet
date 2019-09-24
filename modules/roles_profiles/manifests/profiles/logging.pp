# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging (
    String $worker_type         = '',  # not used by windows
    String $stackdriver_project = 'fx-worker-logging-prod',
    String $syslog_host         = join([
      'log-aggregator',
      "${1 + fqdn_rand(2)}",
      '.srv.releng.',
      regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1'),
      '.mozilla.com'
    ]),
    Integer $syslog_port        = 514,
) {

    # use a single write-only service account for each project
    $stackdriver_keyid    = lookup("stackdriver.${stackdriver_project}.keyid")
    $stackdriver_key      = lookup("stackdriver.${stackdriver_project}.key")
    $stackdriver_clientid = lookup("stackdriver.${stackdriver_project}.clientid")

    case $::operatingsystem {
        'Windows': {

            $location        = $facts['custom_win_location']
            $programfilesx86 = $facts['custom_win_programfilesx86']
            if ($facts['custom_win_location'] == 'datacenter') {
                $conf_file = epp('win_nxlog/nxlog.conf.epp')
            } else {
                $conf_file = file('win_nxlog/non_datacenter_nxlog.conf')
            }

            class { 'win_nxlog':
                nxlog_dir => "${programfilesx86}\\nxlog",
                location  => $location,
                conf_file => $conf_file,
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
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
