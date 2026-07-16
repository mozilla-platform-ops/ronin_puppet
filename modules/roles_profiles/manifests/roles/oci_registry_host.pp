# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Sets up a local, insecure OCI registry for Tart VM images.
#
# The registry is a `registry:2` container running under Docker inside a
# Colima (Lima + Apple Virtualization.framework) VM, published on the host at
# :5000. The whole Tart tester fleet (gecko-t-osx-1500-m-vms) pulls its images
# from here, so this host is single-point-of-failure infrastructure. The
# profiles below add the reboot-resilience, garbage-collection and health
# monitoring that keep it dependable:
#
#   colima_docker  - ensures the docker/lima/colima Homebrew formulae and,
#                    critically, a system LaunchDaemon that (re)starts Colima
#                    at boot and heals it if it dies, so the registry survives
#                    a reboot without a human running `colima start`.
#   oci_registry   - runs the registry:2 container (--restart=always), plus a
#                    daily maintenance job (tag retention + garbage-collect to
#                    stop unbounded disk growth) and a periodic health/disk
#                    check that alerts on trouble.
#
# Homebrew itself is NOT managed here: this host is bootstrapped once with brew
# preinstalled (Apple-Silicon /opt/homebrew, admin-owned). colima_docker asserts
# brew is present and fails with a clear message if it is missing, rather than
# vendoring a full installer.
class roles_profiles::roles::oci_registry_host {
  include roles_profiles::profiles::colima_docker
  include roles_profiles::profiles::oci_registry
}
