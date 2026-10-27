# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# $refresh_minutes and $sbom_dir are deliberately left unset so they resolve
# through automatic parameter lookup: a role that wants a tighter cadence can
# set macos_sbom::refresh_minutes in data/roles/<role>.yaml.
class roles_profiles::profiles::macos_sbom {
  class { 'macos_sbom':
    enabled => true,
  }
}
