# Agents

This document describes the “agent” surface area for `ronin_puppet`: which platforms we target, how they are exercised in CI, and how to extend the integration-testing setup.

> TL;DR: Agents are “Puppet roles + Test Kitchen suites + CircleCI jobs”.
> Each agent definition should be testable via Test Kitchen and, where practical, covered by CircleCI.

---

## 1. Concepts

### Roles, profiles, and agents

`ronin_puppet` follows the standard roles/profiles pattern:

- **Modules** (`modules/`): OS-specific or functional building blocks.
- **Profiles** (`modules/roles_profiles/manifests/profiles`):
  - Provide an OS-independent interface to functionality.
  - Are the place where OS detection and routing happens.
- **Roles** (`modules/roles_profiles/manifests/roles`):
  - Describe everything a machine type needs to fulfill a given purpose.
  - Map to actual device groups and production host classes.

For the purposes of this document:

> **Agent** = a logical machine type, usually represented by
> 1) a **Puppet role**,
> 2) a **Test Kitchen suite**, and
> 3) a **CircleCI job / matrix entry**.

Examples:

- `linux-perf-ubuntu-1804` – Linux perf workers on Ubuntu 18.04
- `linux-perf-ubuntu-2404` – Linux perf workers on Ubuntu 24.04
- `linux-netperf-ubuntu-1804` – Linux netperf workers
- `bitbar-ubuntu-2204` – Bitbar device-pool workers
- `gecko_t_osx_1015_r8` – macOS 10.15 Talos test workers
- (historical / currently disabled) `mac_v3_signing_*` – mac signing agents
- (historical / currently disabled) `geckotwin10641803hw` – Windows build/test agent

Each of these has:

- Puppet role code under `modules/roles_profiles`,
- Test Kitchen config and InSpec/serverspec tests under `test/integration`, and
- CI coverage wired via `.circleci/config.yml`.

---

If you are adding or modifying an agent and something in this document does not match reality, update this file alongside your changes. The goal is that anyone familiar with Puppet and CircleCI can quickly understand which agents exist, how they are tested, and how to extend the matrix safely.
