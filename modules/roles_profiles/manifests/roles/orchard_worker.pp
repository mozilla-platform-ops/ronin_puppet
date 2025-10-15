# Orchard worker role for macOS VM infrastructure.

class roles_profiles::roles::orchard_worker {
  include roles_profiles::profiles::homebrew_install
  include roles_profiles::profiles::orchard_worker
  include roles_profiles::profiles::relops_users
  include roles_profiles::profiles::motd
}
