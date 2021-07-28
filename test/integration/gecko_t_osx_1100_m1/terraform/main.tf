variable "role" {
  type    = string
  default = "gecko_t_osx_1100_m1"
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

resource "vault_generic_secret" "common_yaml_secrets" {
  depends_on = [vault_mount.hiera]
  for_each   = fileset(path.module, "common/*.yaml")
  path       = "hiera/common/vault_secrets::${replace(basename(each.value), ".yaml", "")}"
  data_json  = jsonencode(yamldecode(file("${each.value}")))
}

resource "vault_generic_secret" "role_yaml_secrets" {
  depends_on = [vault_mount.hiera]
  for_each   = fileset(path.module, "roles/*.yaml")
  path       = "hiera/roles/${var.role}/vault_secrets::${replace(basename(each.value), ".yaml", "")}"
  data_json  = jsonencode(yamldecode(file("${each.value}")))
}
