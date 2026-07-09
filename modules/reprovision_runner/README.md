# reprovision_runner

Installs the **Hangar reprovision-runner** on an on-network (MDC1) macOS host.

Hangar (Cloud Run) cannot SSH into MDC1, so it only *queues* reprovision jobs.
This runner lives on the VPN, polls Hangar over **mTLS (outbound only, no inbound
to MDC1)**, claims a job, runs the `reprovision` CLI (from the relops-bootstrap
orchestrator), and streams progress back. It is the **only** component that holds
worker SSH/admin creds; Hangar holds none.

See also: `relops-bootstrap/orchestrator/orchestrator/runner.py` and
`hangar/docs/reprovision-mdc1-runner-design.md`.

## What Puppet manages

- Python 3.11 (framework build, via `packages::python3`)
- A clone of relops-bootstrap + a venv with the orchestrator editable-installed
  (`/opt/reprovision-runner`)
- A **LaunchDaemon** (`com.mozilla.reprovision-runner`, `RunAtLoad` + `KeepAlive`)
  that survives reboots and disconnects — no more foreground ssh session
- A root-only (`0600`) env file the daemon sources: `HANGAR_API_URL`, `RUNNER_*`,
  and the `REPROVISION_*` creds
- The mTLS client cert (see cert modes below)

## Cert modes

`reprovision_runner.cert_mode`:

- **`step_renew`** (default, recommended): Puppet installs the smallstep `step`
  CLI and a **cert-renew LaunchDaemon** (`step ca renew --daemon`). The private
  key is generated **on-host** and never leaves it (nothing in vault/git); certs
  are short-lived and auto-rotated; renewal is mTLS-authenticated by the current
  cert; the cert is centrally revocable. On renewal the runner is kicked
  (`launchctl kickstart`) so it picks up the new cert.
- **`vault`**: cert + key are delivered through `vault.yaml` and written `0600`.
  Simple and ronin-native, but a long-lived key at rest + manual rotation. Use
  only where `step_renew` isn't viable.

## Assigning the role

Point the host at the dedicated role so `bolt plan run deploy::apply` rebuilds
everything:

```
roles_profiles::roles::gecko_t_osx_1500_m4_reprovision_runner
```

Non-secret config: `data/roles/gecko_t_osx_1500_m4_reprovision_runner.yaml`.

## Secrets (vault.yaml, fetched per-host)

Same values the operator CLI resolves from the RelOps 1Password vault:

```yaml
reprovision_runner:
  tc_client_id:       "..."   # op://RelOps/Taskcluster Quarantine/username
  tc_access_token:    "..."   # op://RelOps/Taskcluster Quarantine/password
  simplemdm_api_key:  "..."   # op://RelOps/SimpleMDM API admin/password
  ssh_admin_password: "..."   # op://RelOps/DEP Provisioned Mac Admin Account SimpleMDM SSH/password
  ssh_admin_key: |            # op://RelOps/RelOps Worker Admin Key/notesPlain
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
```

## One-time step-ca bootstrap (`cert_mode: step_renew`)

The renew daemon needs an initial cert. Two supported paths:

1. **Puppet-driven (single-use token in vault):** set in `vault.yaml`

   ```yaml
   reprovision_runner::step_renew::ca_fingerprint: "<root CA SHA-256 fingerprint>"
   reprovision_runner::step_renew::enrollment_token: "<single-use bootstrap token>"
   ```

   Puppet runs `step ca certificate` once (guarded by `creates` on the cert).
   A short-lived, single-use token is far weaker material than a long-lived key.

2. **Operator-driven (no token in vault):** set only `ca_fingerprint`, then once
   on the host:

   ```bash
   export STEPPATH=/var/root/reprovision-runner/step
   step ca bootstrap --ca-url https://step-ca.relops.mozilla --fingerprint <fp>
   step ca certificate "$(hostname -s)" \
     /var/root/reprovision-runner/client.crt \
     /var/root/reprovision-runner/client.key \
     --provisioner <provisioner>
   ```

The cert CN must be the host's short name (e.g. `macmini-m4-81`); Hangar
authorizes the runner on the cert Subject CN against `REPROVISION_RUNNER_HOSTS`.
The SPIFFE SAN role is `gecko_t_osx_1500_m4_no_sip` (matches the step-ca
template used elsewhere).

## Logs

`/var/log/reprovision-runner/{runner,certrenew}.{out,err}`
