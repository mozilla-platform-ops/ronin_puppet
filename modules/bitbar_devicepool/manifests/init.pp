# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool {

  # helpers
  include ::bitbar_devicepool::systemd_reload

  # setup user accounts, etc
  include ::bitbar_devicepool::base
  # install the devicepool app
  include ::bitbar_devicepool::devicepool
  # place android-tools repo
  include ::bitbar_devicepool::android_tools
  # install other utilities
  include ::bitbar_devicepool::last_started_alert
  include ::bitbar_devicepool::worker_health

}
