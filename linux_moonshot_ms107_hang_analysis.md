# ms-107 Hang Analysis — 2026-04-25

## TL;DR

ms-107 is hanging **during boot**, not mid-task. Boot -1 ended cleanly with a
normal `reboot --force` at 17:55 UTC on April 23; the host didn't come back
until 01:00 UTC on April 25 — a **~31-hour silent gap** with no intermediate
journal entries. The candidate mechanisms are an intermittent pre-journald
kernel/firmware hang and repeated SMBus timeouts in the chassis management bus.

---

## What the data shows

**Host:** `t-linux64-ms-107`
**OS:** Ubuntu 24.04.2 LTS, kernel `6.8.0-110-generic`
**Report captured:** 2026-04-25 01:10:58 UTC (10 min after boot 0 started)

### Boot -1 was clean

Boot -1 ran 17:51–17:55 UTC (~4 min). A Raptor Browsertime task
(`idb-open-many-par`, project `try`) ran and completed. The final journal
entries are the expected `run-start-worker` reboot sequence:

```
run-start-worker: + /usr/bin/sudo /sbin/reboot --force
sudo[6076]: cltbld : ... COMMAND=/sbin/reboot --force
```

No kernel panics, no OOM kills, no NVMe errors, no filesystem remounts to `ro`.
The kernel grep for hang patterns returned only benign boot-time messages (nvme
init, ext4 mount).

### The 31-hour silent gap

Boot -1 ended at `17:55:43`. Boot 0 started at `01:00:39` the following day —
31 hours later. `journalctl --list-boots` shows **no intermediate entries**. If
the machine had booted and crashed, nothing was written to the persistent
journal. This points to a hang very early in the boot process — before journald
starts — or to the machine being stuck at POST/firmware level until iLO reset
it.

### Reboot frequency

25 boots recorded on April 23 (12:02–17:55 UTC), all normal task-run cycles of
5–35 minutes. The pathological event is only the 31-hour gap between boot -1
and boot 0.

### Journal corruption

Boot -1's journal was flagged corrupt at startup:

```
systemd-journald[436]: File system.journal corrupted or uncleanly shut down,
renaming and replacing.
```

This confirms that one of the preceding boots (before boot -1) ended abruptly
— consistent with a hard hang or power cycle.

### SMBus timeouts (recurring)

Current-boot dmesg (~14 seconds into boot 0) shows:

```
i801_smbus 0000:00:1f.4: Transaction timeout  (×4)
```

The i801 SMBus controller is the Intel PCH bus used for chassis thermal/fan
management on HP Moonshot. These timeouts recur on every boot observed. If
something in early userspace blocks waiting on SMBus (e.g. `thermald`, IPMI
poller), it could cause a multi-second to indefinite stall before journald is
up and writing.

### pstore / ERST

pstore is enabled and backed by ERST:

```
ERST: Error Record Serialization Table (ERST) support is initialized.
pstore: Registered erst as persistent store backend
```

pstore was **empty** at report time — no kernel panic record survived from the
31-hour gap. This is consistent with either a firmware-level hang (kernel never
ran long enough to write a record) or an iLO-triggered hard reset that cleared
ERST before the OS came up.

### Other observations

- `dis_ucode_ldr` in kernel cmdline — microcode loading intentionally disabled.
  CPU reports MDS/TAA/MMIO vulnerabilities as "no microcode." Confirm this is
  deliberate fleet-wide config.
- `smartctl` not installed (`exit 127`) — NVMe health is blind on all these
  hosts until `smartmontools` is added via puppet.
- `run-puppet.service` took 38.5s — long but completed; not a hang vector.
- No failed systemd units; all filesystems mounted rw.

---

## Root cause hypothesis

**Intermittent firmware/hardware hang during POST or early kernel init,**
triggered by the forced reboot. The SMBus timeouts are a consistent symptom
pointing at the chassis management hardware (HP Moonshot iLO / chassis
backplane). The host boots fine most of the time but occasionally gets stuck
before journald can write anything — leaving a 31-hour silent gap until iLO
resets it.

This is distinct from a userspace or workload-triggered hang: the task on
boot -1 completed normally, and no in-flight hang patterns appeared in the
kernel log.

See also: ms-025 shows an identical pattern (16-hour gap, same SMBus timeouts),
and ms-112 had a cluster of rapid reboots exhibiting the same symptoms.

---

## Next actions

### Immediate (next hung host, before rebooting)

1. **Check pstore for a preserved crash record:**
   ```bash
   ls /sys/fs/pstore/
   cat /sys/fs/pstore/dmesg-erst-* 2>/dev/null | head -200
   ```
   If the kernel panicked or oopsed during the silent boot it will be here.

2. **Check SMBus timeout depth:**
   ```bash
   dmesg | grep -i 'smbus\|i801'
   ```
   Count the timeouts and note whether they appear before or after the point
   where the host goes silent on subsequent reboots.

### Short-term (puppet / fleet)

3. **Install `smartmontools`** so NVMe SMART data is available in future
   reports.

4. **Check whether `dis_ucode_ldr` is intentional fleet config** — if not,
   removing it allows the kernel to apply CPU microcode errata fixes that may
   affect stability.

5. **Cross-check other ms-0xx hosts** for the same `i801_smbus` timeout
   pattern — if it's chassis-wide, it points at the HP Moonshot backplane or
   CM firmware rather than a per-cartridge defect.

6. **Check HP Moonshot CM firmware version** against HPE advisories for
   Moonshot 1500 / ProLiant m710x cartridges — chassis-manager firmware bugs
   causing cartridge hangs on reboot are a known class of issue.

### Medium-term (Phase 3 from runbook)

7. **Enable kdump** — without it, any kernel hang during boot leaves no
   evidence. Even one crash dump from a hung boot would immediately narrow the
   diagnosis.

8. **Enable `kernel.hung_task_panic = 1` + `kernel.softlockup_panic = 1`** on
   a canary cartridge so hangs self-report rather than going silent.
