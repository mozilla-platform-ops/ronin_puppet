# Linux multiuser-static Generic Worker plan

## Purpose

Linux Taskcluster workers currently use the Generic Worker `insecure` engine.
The worker supervisor and every task run as the shared `cltbld` user. This
document records how the macOS `multiuser-static` deployment differs and
outlines a safe Linux migration path.

`multiuser-static` is a deployment convention built on Generic Worker's
`multiuser` binary; it is not a distinct upstream executable or a mode that
runs multiple tasks concurrently. The worker still has
`numberOfTasksToRun: 1` and reboots after a task.

## macOS design

The macOS role selects `generic_worker_engine: multiuser-static` in role data.
`roles_profiles::profiles::worker` passes that engine, plus the static task
user's password, to `worker_runner`.

The module converts the engine name to the upstream
`generic-worker-multiuser` executable. For a `multiuser*` engine it starts
Worker Runner as a root LaunchDaemon, makes `/opt/worker` root-owned, and
writes its runner configuration as `0600`. That configuration contains the
long-lived Taskcluster worker-registration credentials.

At a high level:

```
root LaunchDaemon
  -> worker-runner.sh
      -> start-worker
          -> generic-worker-multiuser (privileged controller)
              -> cltbld LaunchAgent (desktop-session command broker)
                  -> task command as cltbld
```

The `cltbld` LaunchAgent is deliberately not the main Generic Worker. It runs
`generic-worker-multiuser launch-agent`, which provides the desktop-session
side needed to execute GUI tasks. It does not receive the worker-registration
configuration.

### Static task-user selection

Before every worker start, the macOS wrapper changes to `/var/root`. Puppet
places a root-only `/var/root/next-task-user.json` there:

```json
{
  "name": "cltbld",
  "password": "<static-user-password>"
}
```

Generic Worker looks for this file relative to its working directory. It uses
the listed account as the current task user and, because this deployment runs
only one task, does not create a future `task_<id>` account. The file is
`root:wheel`, mode `0600`, so neither a task nor the `cltbld` LaunchAgent can
read it.

### What the macOS boundary protects

The task user does not have access to:

- The Worker Runner configuration, including the long-lived registration
  client ID and access token.
- The worker signing key.
- `next-task-user.json` and `current-task-user.json` in `/var/root`.
- The root Worker Runner / Generic Worker controller processes.

Tasks do receive normal task-scoped credentials through Taskcluster Proxy.
Those credentials are expected to be available to a task and are distinct from
the worker-registration credentials.

This is not per-task isolation: all tasks run as the persistent `cltbld`
account and therefore can leave state in that account's home directory and
caches. The benefit is separation of the privileged worker control plane from
the task process.

### macOS implementation references

- `modules/roles_profiles/manifests/profiles/worker.pp`
- `modules/worker_runner/manifests/init.pp`
- `modules/worker_runner/templates/worker_runner_config.yaml.erb`
- `modules/worker_runner/templates/worker-runner.sh.erb`
- `modules/worker_runner/templates/next-task-user.json.erb`
- `modules/worker_runner/templates/com.mozilla.genericworker.launchagent.plist.erb`
- `data/roles/gecko_t_osx_1500_m4.yaml`

## Current Linux design

Ubuntu 24.04 Talos workers currently install Generic Worker v88.0.2 using the
`generic-worker-insecure` release asset, installed as
`/usr/local/bin/generic-worker`. The `cltbld` GNOME session starts it through
a per-user desktop autostart entry:

```
GDM auto-login as cltbld
  -> GNOME autostart
      -> gnome-terminal
          -> run-start-worker-wrapper.sh
              -> run-start-worker.sh
                  -> start-worker
                      -> generic-worker-insecure
                          -> task command as cltbld
```

The existing `start-worker` configuration is `/etc/start-worker.yml`. It
contains the standalone worker-registration client ID and token and is
currently installed as `root:root`, mode `0644`. Worker task data, caches,
downloads, and signing material are under `/home/cltbld`.

The graphical prerequisite for Linux multiuser is already substantially in
place: the GUI profile enables GDM and configures it to auto-login `cltbld`.
The repository's Linux GUI development notes explicitly describe multiuser GDM
autologin and identify a single-static-user implementation as the missing
work for Talos performance workers.

## Upstream Linux capability

The v88.0.2 Generic Worker source supports
`generic-worker-multiuser-linux-amd64` and
`generic-worker-multiuser-linux-arm64`. Linux amd64 is upstream Tier 1 at that
version.

In non-headless multiuser mode, Generic Worker:

- Runs the controller with the privileges needed to manage task identities and
  file ownership.
- Waits for exactly one GDM/GNOME interactive session matching the selected
  task user.
- Starts task commands under that user's UID, GID, and supplementary groups.
- Sets `DISPLAY=:0` and `XDG_RUNTIME_DIR=/run/user/<uid>` for Linux task
  commands.

Unlike macOS, Linux does not require the Generic Worker `launch-agent`
subcommand. The controller can launch the task command directly as `cltbld`.

## Linux migration plan

### 1. Start with a dedicated Ubuntu 24.04 X11 canary

Do not begin with the legacy 18.04, Wayland, or Netperf roles. Ubuntu 24.04
already uses v88.0.2 and the GDM-based X11 configuration, so it has the fewest
unrelated changes. Prefer a separate canary role or pool before converting an
existing production pool.

### 2. Make the Linux worker engine selectable

Extend `linux_generic_worker` and `packages::linux_generic_worker` with an
explicit engine choice, initially `insecure` or `multiuser-static`.

For `multiuser-static`:

- Download the `generic-worker-multiuser` asset and pin its checksum.
- It is acceptable to continue installing it as
  `/usr/local/bin/generic-worker`; this avoids unnecessary changes to health
  checks and wrapper scripts.
- Retain the existing `start-worker`, proxy, livelog, and quarantine binaries.

### 3. Create a root-owned control-plane directory

Introduce a root-only directory, for example `/var/lib/generic-worker`, as
the working directory of the root service. It must contain:

- `next-task-user.json` and Generic Worker's generated
  `current-task-user.json`.
- Task-resolution counters and other worker bookkeeping.
- Generated Generic Worker configuration and the signing key, or an equally
  protected location for them.

All long-lived registration credentials and signing keys must be root-only.
In particular, change `/etc/start-worker.yml` from `0644` to `0600` for the
multiuser-static path.

For the static user file, first verify whether Linux requires a real password
in the JSON. The upstream Linux path uses the selected account name and the
already-active GDM session to run the task; it does not need to log `cltbld`
in. Avoid placing a plaintext password in the file if an empty value is valid.

### 4. Replace GNOME autostart with a root service

Install a root-owned systemd service which starts after the graphical/GDM
session is available, uses the protected control-plane directory as its
working directory, and retains the existing wait for Puppet completion.

The current `cltbld` GNOME autostart entry must be absent or disabled in this
mode. There must be exactly one worker-start path.

The task will still run as the auto-logged-in `cltbld` desktop user; only the
controller moves to root.

### 5. Rewrite the wrapper for the root boundary

Do not run the present `run-start-worker.sh` unchanged as root. It was written
for a `cltbld` supervisor and currently reads or writes task-user-controlled
paths such as:

- `/home/cltbld/operator_hold`
- `/home/cltbld/quarantined`
- `/home/cltbld/bug_id`
- `/home/cltbld/bug.json`

Running that code as root would turn those paths into a privilege boundary,
including possible symlink and attacker-controlled-content problems. Move
root-controlled state to the new protected directory, make file operations
symlink-safe, and re-evaluate the quarantine/Bugzilla helper before retaining
it in the root service.

The wrapper should preserve the operational behaviors that remain wanted:

- Wait for Puppet completion.
- Honor an operator hold mechanism whose ownership and semantics are clearly
  defined.
- Emit lifecycle events and import Generic Worker metrics.
- Preserve exit-69/quarantine and reboot behavior after it has been made safe.

### 6. Validate GUI and device behavior on the canary

The current insecure worker inherits a GNOME terminal's session environment.
The multiuser controller instead constructs the task environment. Validate:

- Firefox/X11 startup and screenshot capture.
- WebRender/OpenGL and `/dev/dri` access.
- Audio/PipeWire/PulseAudio behavior.
- VNC and display access.
- `DISPLAY`, `XDG_RUNTIME_DIR`, and any required D-Bus session behavior.
- One-task/reboot lifecycle, health checks, Papertrail, and lifecycle logs.

### 7. Add tests before broad rollout

Extend the Linux Kitchen/InSpec coverage to assert at least:

- The selected multiuser binary is installed.
- The root systemd unit exists and the GNOME worker autostart entry is absent
  in static mode.
- Worker-registration configuration, signing material, and control-plane files
  are root-only.
- `next-task-user.json` is root-only and names `cltbld`.
- The rendered service has the intended working directory and ordering.

Kitchen Docker cannot fully validate GDM, a real desktop session, or task
execution under the live worker. The canary needs on-host smoke tasks in
addition to catalog and rendered-file tests.

## Expected security result

After migration, an untrusted task should not be able to read worker
registration credentials, modify worker control files, or directly control the
privileged Worker Runner / Generic Worker processes. It will still share the
persistent `cltbld` account with later tasks, so task-to-task filesystem state
is not isolated. Reboot and targeted cleanup remain important.

## Relevant Linux files

- `modules/packages/manifests/linux_generic_worker.pp`
- `modules/linux_generic_worker/manifests/init.pp`
- `modules/linux_generic_worker/templates/worker-runner-config.yml.erb`
- `modules/linux_generic_worker/templates/run-start-worker.sh.erb`
- `modules/linux_generic_worker/templates/gnome-terminal.desktop.erb`
- `modules/roles_profiles/manifests/profiles/gecko_t_linux_2404_talos_generic_worker.pp`
- `modules/linux_gui/templates/gdm3_custom.conf.erb`
- `modules/linux_gui/README_2404_dev.md`
