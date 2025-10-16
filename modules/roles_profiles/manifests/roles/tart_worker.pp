# Configures a Tart worker able to push/pull from the local registry
class roles_profiles::roles::tart_worker {
  include roles_profiles::profiles::homebrew_silent_install
  include roles_profiles::profiles::tart
}
