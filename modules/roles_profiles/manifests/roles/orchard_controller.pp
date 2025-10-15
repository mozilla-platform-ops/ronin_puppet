# Orchard controller role for macOS VM infrastructure.
# Responsible for running the Orchard control plane and image registry.

class roles_profiles::roles::orchard_controller {
  include roles_profiles::profiles::homebrew_install
  include roles_profiles::profiles::motd
  include roles_profiles::profiles::orchard_controller
}
