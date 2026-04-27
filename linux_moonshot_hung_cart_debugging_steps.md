# Debugging Hung HP Moonshot Linux Cartridges

## Context

`t-linux64-ms-*` cartridges (Ubuntu 18.04 and 24.04 Linux on HP Moonshot
chassis) go unreachable at a rate of several per day. Current mitigation is to
power-cycle the cartridge via iLO Chassis Manager, which works but destroys
all forensic state. The goal of this runbook is to stop guessing and narrow
each hang to one of:

- kernel panic / hang
- userspace wedge (sshd, systemd, fs)
- disk / IO failure (NVMe resets)
- OOM / memory exhaustion
- thermal or power (chassis-level)
- workload-triggered (a specific taskcluster job pattern)

---

## Phase 0 — BEFORE the next reboot

The single highest-value thing you can do is capture state *before* rebooting.
Most of the real evidence is lost the moment the cartridge power-cycles.

1. **iLO Chassis Manager → serial-over-LAN (SOL) console** for the cartridge.
   - `connect host <cartridge-id>` (or the chassis-specific equivalent).
   - A hung-but-alive kernel usually prints `Call Trace`, `BUG:`, `hung task`,
     `soft lockup`, `Out of memory`, or a full panic on the console.
   - Screenshot / copy the buffer. This is your best signal.
2. **iLO chassis health / event log**:
   - Thermal events, PSU events, cartridge power events, NIC link flaps.
   - Note the timestamp of the last event vs. when the host went silent in
     fleetroll `host-monitor`.
3. **Try a degraded-but-alive probe** before pulling the plug:
   - ICMP ping — rules in/out full network loss vs. app-layer hang.
   - TCP to :22 (connect, not full session) — distinguishes "kernel alive,
     sshd wedged" from "kernel dead."
   - If ping works but ssh doesn't, it's almost certainly userspace / fs /
     pid exhaustion, not a kernel panic.
4. If SOL is responsive at all, issue a **sysrq** sequence over the console
   before resetting — this gets you kernel state for free:
   - `Alt-SysRq-t` (task list) → every blocked task's stack
   - `Alt-SysRq-w` (blocked tasks only)
   - `Alt-SysRq-m` (memory state)
   - `Alt-SysRq-l` (backtrace all CPUs)
   - `Alt-SysRq-c` (deliberate crash → kdump, *only* if kdump is configured)
   - Make sure `/proc/sys/kernel/sysrq` is `1` on these hosts; if it isn't,
     that's a config change worth landing fleet-wide.

## Phase 1 — Immediately after the reboot

**The steps differ by OS version.** Ubuntu 18.04 uses volatile journald (logs
lost at reboot) and rsyslog to `/var/log/syslog*`; Ubuntu 24.04 keeps
persistent journals under `/var/log/journal/`. Both versions ship logs
off-box to Papertrail — check Papertrail *first* for any host that is already
unreachable, since those logs survive the power-cycle.

### 18.04 hosts (`gecko_t_linux_talos` role)

1. **Papertrail first — off-box, survives the hang (highest signal):**
   - Query Papertrail for `host:t-linux64-ms-<id>` covering the 30 minutes
     before the host went silent in `fleetroll host-monitor`.
   - Look for: `hung task`, `soft lockup`, `Call Trace`, `oom-kill`,
     `I/O error`, `ext4-fs error`, `nvme`, `mce`, `BUG:`, `panic`.
   - Identifiers shipped: `generic-worker`, `run-start-worker`, `sudo`,
     plus units `check_gw`, `run-puppet`, `ssh`.
2. **On-box rotated syslog** (after reboot):
   ```bash
   sudo ls -la /var/log/syslog* /var/log/kern.log* /var/log/dmesg* /var/log/auth.log*
   sudo zgrep -iE 'hung task|soft lockup|call trace|oops|panic|bug:|oom-kill|invoked oom|blocked for more than|i/o error|ext4-fs error|nvme|mpt|mce' \
       /var/log/syslog.1 /var/log/kern.log.1 /var/log/syslog.2.gz /var/log/kern.log.2.gz 2>/dev/null
   sudo tail -2000 /var/log/syslog.1
   ```
3. **Current-boot journal** (volatile — try this *before* rebooting if the
   box is still up from the previous boot):
   ```bash
   journalctl -k --no-pager | tail -500
   journalctl --no-pager | tail -2000
   ```
4. **Kernel crash dumps:** `ls -la /var/crash/` — kdump not installed, but
   confirm.
5. **Boot history:** `last -x reboot | head -30`, `who -b`, `uptime`.
6. **Hardware health:**
   ```bash
   sudo smartctl -a /dev/nvme0n1   # or /dev/sda
   sudo dmesg -T | grep -iE 'error|fail|reset|timeout'
   ```
7. **Systemd post-boot sanity:**
   ```bash
   systemctl --failed
   systemd-analyze blame | head -20
   ```

### 24.04 hosts (`gecko_t_linux_2404_talos` role)

Ubuntu 24.04 keeps persistent journals by default under `/var/log/journal/`,
but confirm.

1. **Previous-boot kernel log (highest signal):**
   ```bash
   journalctl -k -b -1 --no-pager | tail -500
   journalctl -k -b -1 | grep -iE 'hung task|soft lockup|call trace|oops|panic|bug:|oom-kill|invoked oom|blocked for more than|i/o error|ext4-fs error|nvme|mpt|mce'
   ```
2. **Previous-boot full journal, last 10 minutes before the hang:**
   ```bash
   journalctl -b -1 --no-pager | tail -2000
   ```
   Look at the *last lines written* — that's what was happening when it
   wedged.
3. **Kernel crash dumps:** `ls -la /var/crash/` (kdump) and
   `/var/lib/systemd/coredump/`. If kdump isn't enabled, enabling it on these
   boxes is probably the single best ROI change for future incidents.
4. **Boot history & uptime pattern:**
   ```bash
   last -x reboot | head -30
   journalctl --list-boots | head -30
   ```
   Look for: regular interval (→ watchdog/cron/thermal cycle), clustered
   times (→ shared trigger), or correlation with a specific taskcluster job
   window.
5. **Hardware health:**
   ```bash
   sudo smartctl -a /dev/nvme0n1   # or /dev/sda
   sudo dmesg -T | grep -iE 'error|fail|reset|timeout'
   ```
   Moonshot cartridges have packed thermals and shared backplane — repeated
   NVMe resets or link renegotiation are classic symptoms.
6. **Memory / OOM forensics:**
   ```bash
   journalctl -b -1 | grep -iE 'oom|killed process|out of memory'
   ```
7. **Filesystem:** `dmesg | grep -i ext4`, check `mount` for read-only
   remounts.
8. **Systemd post-boot sanity:**
   ```bash
   systemctl --failed
   systemd-analyze blame | head -20
   ```

## Phase 2 — Pattern analysis across the fleet

One host is an anecdote; "a bunch a day" is the actual problem. Use
fleetroll + journal aggregation to find what's common.

1. **Cross-host hang timestamps.** From `host-monitor` / the observations DB,
   list every `t-linux64-ms-*` that went unreachable in the last 7 days and
   the wall-clock time they went silent. Look for:
   - Same chassis? (ms-084 and ms-064 — are they in the same Moonshot
     enclosure? Check naming convention / inventory. If yes, suspect
     chassis-level: shared PSU, shared switch backplane, firmware.)
   - Same kernel / same puppet role SHA? (`fleetroll audit` / observations).
   - Same time-of-day? (cron, puppet run, backup window, thermal peak.)
2. **Cross-OS correlation.** If both 18.04 and 24.04 cartridges are hanging
   on the same chassis → strongly chassis/firmware, not OS. If only one OS
   version is affected across *many* chassis → OS/kernel/workload.
3. **Kernel version on 18.04 hosts.** Run `uname -r` on a rebooted survivor.
   18.04 ships 4.15 by default; with HWE it may be 5.4+. Note the version and
   check whether all hung hosts share it — a kernel regression is on the table
   given 18.04 is EOL.
4. **Running taskcluster workload at time of hang.** If taskcluster has
   per-worker job logs, check what job was running on each hung worker in
   the final minute before silence — a bad workload (e.g. a test that
   fork-bombs or fills /tmp) would be a strong signal.
5. **Firmware / BIOS / iLO Chassis Manager versions.** HP Moonshot has had
   real-world cartridge-hang bugs fixed in chassis manager firmware updates.
   Check installed CM version vs. HPE's latest advisories for Moonshot 1500
   / ProLiant m710x (or whatever cartridge model these are).
6. **Check beads for any prior investigation of this symptom:**
   ```bash
   br list --status=open   | grep -iE 'hang|unreachable|moonshot|ms-'
   br list --status=closed | grep -iE 'hang|unreachable|moonshot' | head
   ```

## Phase 3 — Make the *next* hang diagnosable (preventive)

Assuming phase 1 doesn't find a smoking gun, land these so the *next* hang
leaves evidence. These apply to **both 18.04 and 24.04** — implement in a
shared puppet profile (e.g.
`modules/roles_profiles/manifests/profiles/linux_hang_forensics.pp`) included
from both `roles/gecko_t_linux_talos.pp` (18.04) and
`roles/gecko_t_linux_2404_talos.pp` (24.04):

1. **Ensure persistent journald:** `Storage=persistent` in
   `/etc/systemd/journald.conf`, `SystemMaxUse=1G` or similar. This is the
   single biggest win on **18.04** where journald is volatile by default —
   all on-box kernel history is currently lost at reboot unless Papertrail
   caught it.
2. **Enable kdump** (package `kdump-tools`, set `crashkernel=` via the
   existing `modules/grub` module — note the existing 18.04/lvm/efi timeout
   quirk in `modules/grub/manifests/init.pp`). Writes a vmcore to
   `/var/crash/` on kernel hang/panic → actual stack traces.
3. **Enable sysrq:** `kernel.sysrq=1` in sysctl.
4. **Enable hung-task + softlockup panic on hang** so the box reboots itself
   into a clean state *with* a crash dump instead of hanging silently:
   ```
   kernel.hung_task_panic = 1
   kernel.hung_task_timeout_secs = 300
   kernel.softlockup_panic = 1
   kernel.panic_on_oops = 1
   kernel.panic = 10     # reboot 10s after panic
   ```
   Gate behind a puppet flag so you can roll it to a canary cartridge first —
   on **18.04** (EOL) kernel-behaviour changes carry slightly more risk since
   there is no upstream fix path; start with one cartridge.
5. **Remote syslog to a collector** (Papertrail is already wired in for
   18.04 hosts; confirm 24.04 has the same). Last-gasp messages get off-box
   before the hang completes.
6. **Cheap liveness probe from a neighbor / jumphost**: every 30s, log
   `ping + tcp:22 + ssh uptime` per cartridge. Distinguishing the three
   failure modes in post-mortem is 80% of the diagnosis.

## You have the answer when...

You'll have diagnosed the class of failure when you can fill in all three:

- **Where it hung:** kernel (stack trace from console / kdump /
  `journalctl -k -b -1`), userspace (sshd/agetty logs, blocked-task dump),
  or environment (chassis event log, thermal, power, network).
- **What triggered it:** correlated with a workload, a cron, a firmware
  bug, or a resource exhaustion curve visible in journald/atop history.
- **Why it's recurring across cartridges:** chassis-shared component,
  shared image/kernel/firmware version, or shared workload.

If phase 1 produces no console trace, no crash dump, and no suspicious log
entries — that itself is the diagnosis: the box is dying without writing to
disk, which points at kernel hang before flush, power/thermal, or the iLO
cutting it off. On **18.04**, Papertrail is the only log source that can
survive the hang; if Papertrail shows nothing either, the box stopped logging
before the fault. Phase 0 (serial console) and Phase 3 (kdump +
hung_task_panic + persistent journald) are how you escape that blind spot.

## Tools referenced

- `fleetroll host-monitor` + observations DB — cross-host timing pattern.
- `fleetroll audit` — role SHA / config drift across hung hosts.
- iLO Chassis Manager web UI + SOL console — primary Phase 0 tool.
- **Papertrail** — off-box log sink for 18.04 hosts; survives power-cycles.
  Query `host:t-linux64-ms-<id>` over the hang window before rebooting.
- `/var/log/journal/`, `/var/crash/`, `/var/lib/systemd/coredump/` on-host
  (24.04 with persistent journald, or 18.04 after Phase 3 is landed).
- `/var/log/syslog*`, `/var/log/kern.log*` on-host — 18.04 pre-Phase-3 only.
- `br` beads tracker — check prior incidents, file a new bead if this
  becomes a standing investigation.
