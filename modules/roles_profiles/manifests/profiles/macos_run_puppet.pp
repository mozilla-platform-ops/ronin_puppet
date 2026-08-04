# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::macos_run_puppet {
  # Off by default; opted into per role via data/roles/<role>.yaml. CI workers
  # converge through the task lifecycle and must not get a second apply firing
  # under a running job — only off-CI hosts that nothing else converges want this.
  $sched = lookup('macos_run_puppet::schedule', Hash[String, Data], 'deep', {})

  class { 'macos_run_puppet':
    enabled           => true,
    schedule_enabled  => pick_default($sched['enabled'], false),
    schedule_interval => pick_default($sched['interval'], 3600),
  }
}
