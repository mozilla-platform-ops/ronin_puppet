# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs net-snmp on macOS workers from the standard packages S3 bucket.
# Used by the macos_snmpd module so marlin can poll macOS workers the same
# way it polls Linux workers (snmpd extend OIDs for gw_status and worker_pool_id).
#
# The .pkg artifact must exist at the configured S3 path before this runs.
# See packages::macos_package_from_s3 for the bucket/path conventions.
class packages::net_snmp (
  String $version = '5.9.4',
) {
  packages::macos_package_from_s3 { "net-snmp-${version}.pkg":
    os_version_specific => true,
    type                => 'pkg',
  }
}
