# Sets up a local, insecure OCI registry for Tart VM images
class roles_profiles::roles::oci_registry_host {
  include roles_profiles::profiles::homebrew_silent_install
  include roles_profiles::profiles::colima_docker
  include roles_profiles::profiles::oci_registry
}
