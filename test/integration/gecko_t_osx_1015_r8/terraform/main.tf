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
