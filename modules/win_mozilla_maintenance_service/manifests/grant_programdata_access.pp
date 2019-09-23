# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service::grant_programdata_access {

    require win_mozilla_maintenance_service::install

    $mozilla_programdata = "${facts['custom_win_programdata']}\\Mozilla"

    file { $mozilla_programdata:
        ensure => directory,
    }

    # using resource puppetlabs-acl
    acl { $mozilla_programdata:
        permissions                =>   {
                                            identity    => 'everyone',
                                            rights      => ['full'],
                                            type        => 'allow',
                                            child_types => 'all',
                                            affects     => 'all'
                                        },
        inherit_parent_permissions => true,
  }
}
