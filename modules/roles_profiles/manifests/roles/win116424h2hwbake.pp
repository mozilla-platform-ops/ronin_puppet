# BAKE role for the wim-packer pipeline.
#
# This is win116424h2hw with the DEPLOY-TIME / machine-specific / hardware
# profiles removed, so it can run on a reference VM and be Sysprep-generalized
# and captured into a golden install.wim. The removed profiles run at first boot
# on the real NUC (via the full win116424h2hw role):
#
#   - windows_worker_runner  : generic-worker/worker-runner registration; pulls
#                              client_id + taskcluster_access_token from Vault and
#                              worker_id=hostname / worker_pool_id from the registry
#                              seed. MUST NOT be baked into a generalized image.
#   - microsoft_kms          : KMS activation; a generalized image loses activation,
#                              so re-activate per-machine at deploy.
#   - nuc_bios               : flashes NUC13 BIOS; physical-hardware only.
#   - nuc_management         : datacenter management scripts (incl. PXE redeploy);
#                              physical/datacenter only.
#   - scheduled_tasks        : runtime/operational tasks — maintain_system
#                              (maintainsystem-hw.ps1 at startup), self_redeploy_check
#                              (can trigger a PXE redeploy), gw_exe_check, task-user
#                              logon init. Excluded so they don't fire during the bake
#                              or on the generalized image's first boot before the
#                              deploy-time run; the full role registers them at deploy.
#   - hardware_observability : installs/configures win_nsclient (monitoring agent) and
#                              looks up `marlin_pw` from Vault. Deployment-time config
#                              tied to the datacenter/monitoring endpoint, not stable
#                              catalog — applied at deploy so no monitoring secret is
#                              baked into the generalized image.
#   - windows_datacenter_administrator : sets the local admin account password from
#                              `win_adminpw` (Vault). Deployment-time identity/secret —
#                              MUST NOT be baked; applied at deploy.
#
# Consequence: the bake role references NO Vault secrets, so the bake needs only an
# empty/placeholder vault.yaml (see win-hw-wim/scripts/bake-bootstrap.ps1). No
# worker-registration secrets are baked either, because windows_worker_runner is
# excluded above.
class roles_profiles::roles::win116424h2hwbake {
  include roles_profiles::profiles::chocolatey
  ## Install before Windows Updates is disabled.
  include roles_profiles::profiles::microsoft_tools
  include roles_profiles::profiles::ssh
  # System
  include roles_profiles::profiles::disable_services
  include roles_profiles::profiles::error_reporting
  include roles_profiles::profiles::suppress_dialog_boxes
  include roles_profiles::profiles::files_system_managment
  include roles_profiles::profiles::firewall
  # hardware_observability (win_nsclient monitoring) excluded — deploy-time; see header.
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::power_management
  # scheduled_tasks intentionally excluded from the bake (runtime/operational;
  # registered at deploy time). See header.
  include roles_profiles::profiles::hardware
  include roles_profiles::profiles::virtual_drivers
  # windows_datacenter_administrator (admin account password) excluded — deploy-time; see header.

  # Adminstration
  include roles_profiles::profiles::logging
  include roles_profiles::profiles::mercurial

  # Worker (stable toolchain only — registration is deploy-time)
  include roles_profiles::profiles::git
  include roles_profiles::profiles::mozilla_build
  include roles_profiles::profiles::mozilla_maintenance_service
  # TODO(wim-bake): Chrome is baked here and can go stale between bake and deploy.
  # Ensure it is refreshed to current (deploy-time re-apply / auto-update) BEFORE the
  # first worker-runner start, so jobs run against an up-to-date Chrome. Revisit.
  include roles_profiles::profiles::google_chrome
}
