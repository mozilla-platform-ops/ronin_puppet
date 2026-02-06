# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging (
  String $worker_type         = '',  # not used by windows
  String $stackdriver_project = 'none',
  String $syslog_host         = 'syslog1.private.mdc1.mozilla.com',
  Integer $syslog_port        = 514,
  String $mac_log_level       = '17',
  Boolean $tail_worker_logs   = false,
  Optional[String] $worker_stdout = undef,
  Optional[String] $worker_stderr = undef,
) {
  # use a single write-only service account for each project
  $stackdriver_keyid    = lookup("stackdriver.${stackdriver_project}.keyid", { 'default_value' => '' })
  $stackdriver_key      = lookup("stackdriver.${stackdriver_project}.key", { 'default_value' => '' })
  $stackdriver_clientid = lookup("stackdriver.${stackdriver_project}.clientid", { 'default_value' => '' })

  case $facts['os']['name'] {
    'Darwin': {
      class { 'fluentd':
        worker_type          => $worker_type,
        stackdriver_project  => $stackdriver_project,
        stackdriver_keyid    => $stackdriver_keyid,
        stackdriver_key      => $stackdriver_key,
        stackdriver_clientid => $stackdriver_clientid,
        syslog_host          => lookup('papertrail.host', { 'default_value' => $syslog_host }),
        syslog_port          => Integer(lookup('papertrail.port', { 'default_value' => $syslog_port })),
        mac_log_level        => $mac_log_level,
        tail_worker_logs     => $tail_worker_logs,
        worker_stdout        => $worker_stdout,
        worker_stderr        => $worker_stderr,
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
