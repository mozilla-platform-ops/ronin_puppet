# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Sets up the local, insecure OCI registry that serves Tart VM images to the
# gecko-t-osx-1500-m-vms tester fleet.
#
# The registry runs as a NATIVE macOS process: the distribution `registry`
# (v3) binary served by a launchd daemon, storing images on the local
# filesystem. There is no Docker/Colima/VM in the path.
#
# History: this used to run as a `registry:2` container inside a Colima VM, but
# Colima did not survive host reboots (the lima guest agent could not reconnect
# over vsock, so the host port-forward that publishes :5000 never came back, and
# the VZ backend needed a GUI session). Running the registry natively removes
# that entire failure class — a plain launchd KeepAlive daemon comes back on its
# own after any reboot, with no session dependency. The on-disk data format is
# unchanged (distribution v3 reads the v2 filesystem layout), so the migration
# reused the existing image data in place.
class roles_profiles::roles::oci_registry_host {
  include roles_profiles::profiles::oci_registry
}
