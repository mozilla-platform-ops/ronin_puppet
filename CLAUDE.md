# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

ronin_puppet is Mozilla's masterless Puppet configuration for Firefox CI workers. It configures Taskcluster workers across Windows, macOS, and Linux using the **Roles & Profiles** pattern.

## Commands

### Setup
```bash
gem install bundler:2.5.23
bundle install
bundle exec r10k puppetfile install --moduledir=r10k_modules -v --force
```

### Linting
```bash
# Run all pre-commit hooks (puppet-lint, puppet-validate, shellcheck, erb/epp-validate, terraform-fmt)
pre-commit run --all-files

# Run specific hooks
pre-commit run puppet-lint --all-files
pre-commit run puppet-validate --all-files
pre-commit run shellcheck --all-files
```

puppet-lint runs with `--fix --fail-on-warnings --no-documentation-check --no-slash_comments --no-unquoted_resource_title --no-140chars-check`.

### Test Kitchen (Docker)
```bash
# Converge a specific suite (Linux)
./bin/kitchen_docker converge linux-perf-ubuntu-2404

# Run InSpec/Serverspec tests
./bin/kitchen_docker verify linux-perf-ubuntu-2404

# Full test cycle (converge + verify + destroy)
./bin/kitchen_docker test linux-perf-ubuntu-2404

# Login to a converged instance
./bin/kitchen_docker login linux-perf-ubuntu-2404

# List available suites
./bin/kitchen_docker list
```

Docker kitchen suites tested in CI: `linux-perf-ubuntu-1804`, `linux-perf-ubuntu-2404`, `linux-netperf-ubuntu-1804`, `bitbar-ubuntu-2204`.

### Test Kitchen (macOS / Windows)
macOS and Windows use separate kitchen configs (`.kitchen_configs/kitchen.circleci.yml` and `.kitchen_configs/kitchen.windows.yml`). These run in CI via GitHub Actions but are not typically run locally.

## Architecture

### Roles & Profiles Pattern

```
Role → includes Profiles → instantiates Modules → reads Hiera data
```

- **Roles** (`modules/roles_profiles/manifests/roles/`): One class per machine type. Each role includes a set of profiles. Roles map directly to Taskcluster worker pool types (e.g., `gecko_t_linux_2404_talos`, `win116424h2azure`).
- **Profiles** (`modules/roles_profiles/manifests/profiles/`): OS-independent interfaces. Profiles do OS detection via `$facts['os']['name']`, perform Hiera lookups, and pass resolved parameters to module classes.
- **Modules** (`modules/`): Component modules implementing specific functionality, usually single-OS. Prefixed by platform: `linux_*`, `macos_*`, `win_*`.

### Structural Rules

1. **Profiles cannot call other profiles** (exception: base OS profiles like `linux_base`).
2. **Profiles cannot be included from within component modules** — only from roles.
3. **Hiera lookups only happen in profiles**, then values are passed as class parameters to modules.

### Hiera Data Hierarchy

Defined in `hiera.yaml` (Linux/macOS) and `win_hiera.yaml` (Windows):

```
data/
  secrets/vault.yaml          # Vault-generated secrets
  roles/<puppet_role>.yaml    # Per-role overrides (worker versions, packages, pool IDs)
  os/<os_family>.yaml         # Per-OS defaults (Windows.yaml, Darwin.yaml, Debian.yaml)
  common.yaml                 # Global defaults (NTP, users, SSH keys, signing config)
```

Role classification comes from the `puppet_role` fact (Linux/macOS) or `custom_win_role` fact (Windows).

### External Modules

`r10k_modules/` contains Puppet Forge modules managed by `Puppetfile` and installed via `r10k`. Do not edit files in `r10k_modules/` directly.

### Entry Point

`manifests/site.pp` sets global variables (`$root_user`, `$root_group`) per OS. Node classification happens via facts, not node definitions.

### Testing

- **InSpec tests**: `test/integration/<suite>/inspec/` — used for Linux suites
- **Serverspec tests**: `test/integration/<suite>/serverspec/` — used for macOS/Windows suites
- **Terraform fixtures**: Some test suites (e.g., `mac_v3_signing_dep`) include Terraform configs for provisioning test infrastructure

### CI Workflows (`.github/workflows/`)

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `pre-commit.yml` | Push/PR to master | Runs all pre-commit hooks |
| `r10k.yml` | Push/PR to master | Validates Puppetfile dependencies |
| `kitchen-linux.yml` | Push/PR to master | Docker-based Kitchen converge+verify for Linux suites |
| `kitchen-macos.yml` | Push/PR to master | Kitchen tests for macOS roles |
| `kitchen-windows.yml` | Push/PR to master | Azure-based Kitchen tests for Windows roles |

### Provisioners

`provisioners/{linux,macos,windows}/` contain bootstrap scripts that install Puppet and run the initial `puppet apply` on fresh machines. These are used during worker image creation, not during normal development.
