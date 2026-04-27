# ms-025 Hang Analysis — 2026-04-23

## TL;DR

ms-025 is hanging **during boot**, not mid-task. The previous boot ended cleanly
with a normal `reboot --force` at 07:11 UTC; the host didn't come back until
23:09 UTC — a 16-hour silent gap with no intermediate journal entries. The
candidate mechanisms are an intermittent pre-journald kernel/firmware hang and
repeated SMBus timeouts in the chassis management bus.

---

## What the data shows

**Host:** `t-linux64-ms-025.test.releng.mdc1.mozilla.com`
**OS:** Ubuntu 24.04.2 LTS, kernel `6.8.0-110-generic`
**Report captured:** 2026-04-23 23:10 UTC (1 min after boot 0 started)

### Boot -1 was clean

Boot -1 ran 05:28–07:11 UTC (~1h43m). A Talos task (`aOwNga4zRva41lqci5r16A`,
pool `releng-hardware/gecko-t-linux-talos-2404`) ran from 06:34 to 07:11 and
finished successfully. The final journal entries are the expected
`run-start-worker` reboot sequence:

```
generic-worker: Task aOwNga4zRva41lqci5r16A finished successfully!
generic-worker: Exiting worker with exit code 0
run-start-worker: + /usr/bin/sudo /sbin/reboot --force
```

No kernel panics, no OOM kills, no NVMe errors, no filesystem remounts to `ro`.
The kernel grep for hang patterns returned only benign boot-time messages (nvme
init, ext4 mount).

### The 16-hour silent gap

Boot -1 ended at `07:11:24`. Boot 0 started at `23:09:30` — 16 hours later.
`journalctl --list-boots` shows **no intermediate entries**. If the machine had
booted and crashed, nothing was written to the persistent journal. This points
to a hang very early in the boot process — before journald starts — or to the
machine being physically powered off the entire time and then power-cycled by
iLO at 23:09.

### Reboot frequency

28+ reboots in ~30 hours (Wed Apr 22 16:16 – Thu Apr 23 23:09). Most short
boots (~5–25 min) are consistent with quick task runs followed by the normal
post-task reboot. The pathological event is only the 16-hour gap between
boot -1 and boot 0.

### SMBus timeouts (recurring)

Current-boot dmesg (14 seconds into boot 0) shows:

```
i801_smbus 0000:00:1f.4: Transaction timeout  (×4)
```

The i801 SMBus controller is the Intel PCH bus used for chassis thermal/fan
management on HP Moonshot. These timeouts recur on every boot observed. If
something in early userspace blocks waiting on SMBus (e.g. `thermald`,
`lm-sensors`, IPMI poller), it could cause a multi-second to indefinite stall
before journald is up and writing.

### pstore / ERST is enabled but unchecked

The kernel is configured with `pstore` backed by ERST (non-volatile firmware
RAM):

```
pstore: Registered erst as persistent store backend
```

If the machine panicked during the silent 16-hour boot attempt, a crash record
may survive in `/sys/fs/pstore/`. This was **not checked** in the ms-025 report
because the hang had already ended before the script ran.

### Other observations

- `dis_ucode_ldr` in kernel cmdline — microcode loading intentionally disabled.
  CPU reports MDS/TAA/MMIO vulnerabilities as "no microcode." Probably
  deliberate; confirm it's fleet-wide config.
- `smartctl` not installed (`exit 127`) — NVMe health is blind on all these
  hosts until `smartmontools` is added via puppet.
- `NetworkManager-wait-online.service` failed (1m26s timeout) — benign on its
  own but confirms the host is slow to acquire a network address, which could
  interact with early-boot services that expect connectivity.

---

## Root cause hypothesis

**Intermittent firmware/hardware hang during POST or early kernel init,**
triggered by the forced reboot. The SMBus timeouts are a consistent symptom
pointing at the chassis management hardware (HP Moonshot iLO / chassis
backplane). The host boots fine most of the time but occasionally gets stuck
before journald can write anything — leaving a 16-hour (or more) silent gap
until iLO resets it.

This is distinct from a userspace or workload-triggered hang: the task on
boot -1 completed normally, and no in-flight hang patterns appeared in the
kernel log.

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
   dmesg | grep -i smbus
   dmesg | grep -i i801
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
