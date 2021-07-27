variable "role" {
  type    = string
  default = "gecko_t_osx_1015_r8"
}

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

provider "vault" {
  # It is strongly recommended to configure this provider through the
  # environment variables described above, so that each user can have
  # separate credentials set in the environment.
  #
  # This will default to using $VAULT_ADDR
  # But can be set explicitly
  # address = "https://vault.example.net:8200"
}

resource "vault_mount" "hiera" {
  path        = "hiera"
  type        = "kv"
  description = "Ronin Puppet Hiera Secret Store"
  options = {
    version = 2
  }
}

resource "vault_generic_secret" "common_telegraf" {
  depends_on = [vault_mount.hiera]
  path       = "hiera/common/vault_secrets::telegraf"

  data_json = <<EOT
{
  "password": "password_value_test",
  "user": "user_value_test"
}
EOT
}

resource "vault_generic_secret" "role_cltbld" {
  depends_on = [vault_mount.hiera]
  path       = "hiera/roles/${var.role}/vault_secrets::cltbld_user"

  data_json = <<EOT
{
  "iterations": "432432",
  "kcpassword": "testing",
  "password": "testing",
  "salt": "testing"
}
EOT
}

resource "vault_generic_secret" "role_generic_worker" {
  depends_on = [vault_mount.hiera]
  path       = "hiera/roles/${var.role}/vault_secrets::generic_worker"

  data_json = <<EOT
{
  "taskcluster_access_token": "taskcluster_access_token_value_test",
  "taskcluster_client_id": "taskcluster_client_id_value_test"
}
EOT
}
