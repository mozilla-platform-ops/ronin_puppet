variable "role" {
  type = string
}

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "2.22.1"
    }
  }
}

provider "vault" {}

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
