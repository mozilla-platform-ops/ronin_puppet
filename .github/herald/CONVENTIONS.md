# ronin_puppet conventions (for Herald reporter and AI summaries)

This document describes the ronin_puppet conventions that the Herald
reporter workflow relies on to map a commit's changed files to
**entities** (what the commit directly touched) and **impact** (which
worker pools / Azure custom images are affected transitively).

The reporter workflow inlines this file into the prompt sent to the
LLM that writes the human-readable summary, so the AI can use the same
terminology and assumptions a ronin reviewer would.

---

## Repo shape

| Path | Meaning |
|---|---|
| `modules/roles_profiles/manifests/roles/<role_id>.pp` | A **role**. One Puppet class per machine type; 1:1 with a Taskcluster worker pool unless the name contains `azure` (see below). ~63 roles total. |
| `modules/roles_profiles/manifests/profiles/<profile_id>.pp` | A **profile**. OS-independent interface composed by roles. Profiles may `include`/`require` other profiles, and they reference component modules. |
| `modules/<module>/manifests/...` (anything except `modules/roles_profiles/`) | A **module**. Reusable Puppet code (e.g., `linux_snmpd`, `generic_worker`, `macos_xcode_tools`). |
| `data/roles/<role_id>.yaml` | Per-role Hiera data — **role-hiera**. |
| `data/os/<Family>.yaml` (`Debian`, `Darwin`, `Windows`) | Per-OS Hiera data — **os-data**. Applies to every role whose OS matches. |
| `data/common.yaml` | Global Hiera data — **common-data**. Applies to every role. |
| `r10k_modules/**` | Vendored external Puppet modules (pinned via `Puppetfile`). **Excluded** from Herald entity tracking; not authored in this repo. |

## Entity types emitted in `entities[]`

The reporter records only **directly-touched** entities here:

| Entity `type` | `id` source | When |
|---|---|---|
| `role` | filename stem | A role's `.pp` changed |
| `profile` | filename stem | A profile's `.pp` changed |
| `module` | top-level dir name under `modules/` | Any file under a non-`roles_profiles` module changed |
| `role-hiera` | filename stem | A `data/roles/<role>.yaml` changed |
| `os-data` | filename stem | `data/os/<Family>.yaml` changed |
| `common-data` | constant `common` | `data/common.yaml` changed |

Anything else (e.g., `.github/`, `README.md`, integration tests outside a
recognizable role path) does not produce an entity and may produce a
commit with zero entities — those commits are skipped, not emitted.

## Worker pools vs Azure custom images

Every role with a name **not** containing `azure` (case-insensitive)
maps 1:1 to a Taskcluster **worker pool** with the same identifier.
Roles whose name contains `azure` are **Azure custom images** —
Herald tracks them separately because their "go-live" semantics differ
from a worker pool deployment.

This split is captured in `impact.worker_pools[]` and
`impact.azure_images[]`. The split is purely a name match; there is no
other source of truth in this repo.

## Staging/alpha exclusion

Roles, profiles, and per-role Hiera files whose names match the
following are **excluded** from both `entities[]` and `impact`:
- name ends with `_staging` (e.g., `gecko_1_b_osx_1015_staging`)
- name contains `alpha` substring (e.g., `win116424h2hwalpha`,
  `win116424h2hwrefalpha`)

Pre-prod and experimental machines should not show up in changelogs
intended for operational visibility.

## Impact derivation

`impact.worker_pools[]` and `impact.azure_images[]` are the union of
roles affected by each touched entity, bucketed by the azure rule above.

| Touched entity | Rule |
|---|---|
| `role` / `role-hiera` | The role itself. |
| `profile` | Every role that transitively includes the profile (closure over `include roles_profiles::profiles::<p>` and `require roles_profiles::profiles::<p>` in role manifests, plus the same in profile manifests so profile→profile chains are followed). |
| `module` | Every profile that references the module (`include <m>::*` / `require <m>::*` / `class { '<m>::*': ... }`), expanded out through the profile closure to the roles that include any profile in that set. |
| `os-data` for `<Family>` | Every role whose name contains one of the OS hints: `Debian` → `linux`; `Darwin` → `mac`, `osx`, `darwin`; `Windows` → `win`. |
| `common-data` | Every (non-staging/alpha) role. |

OS family inference is a heuristic on the role name — accurate for the
current ronin naming convention (`gecko_t_linux_*`, `gecko_t_osx_*`,
`win*`, `mac*`) but may miss future roles that don't encode OS in their
name. When in doubt, treat impact as a best-effort lower bound.

## Notes for AI summarization

When you write the `description` and `headline` for an event:
- Use the exact terminology above: "worker pool" (not "pool"), "Azure
  custom image" (not just "image" or "AMI"), "role", "profile", "module",
  "Hiera".
- If the commit only touches a module, note which profile(s) consume it
  and which roles are downstream (the `impact` block contains that
  information).
- Distinguish between an OS-wide change (`data/os/Windows.yaml` →
  affects every Windows role) and a per-role override
  (`data/roles/<role>.yaml`).
- Don't speculate about rollout timing or staging promotion — Herald
  reports what changed in source, not what's running where.
