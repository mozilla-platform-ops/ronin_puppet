# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class maas::region () {

  include ::maas::prereqs
  include apt

  # see https://maas.io/docs/install-from-packages

  # use ppa for latest builds (recommended in installation docs)
  apt::ppa { 'ppa:maas/2.7':
    notify => Exec['apt_update']
  }

  # sudo apt install maas-region-controller
  package { 'maas-region-controller':
      ensure => present,
  }

}
