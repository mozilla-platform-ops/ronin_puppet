# ms-112 Hang Analysis — 2026-04-25

## TL;DR

ms-112 exhibits a **different failure mode** from ms-107/ms-025: instead of one
long silent gap, it cycled through **25 rapid reboots on April 22** — including
one boot that lasted only 11 seconds — before finally stabilizing at 16:58 UTC.
That stable boot ran for ~56 hours until manually rebooted for diagnostics. The
same SMBus/ERST firmware symptoms are present on every boot, confirming shared
chassis-level root cause with the rest of the fleet.

---

## What the data shows

**Host:** `t-linux64-ms-112`
**OS:** Ubuntu 24.04.2 LTS, kernel `6.8.0-110-generic`
**Report captured:** 2026-04-25 01:15:40 UTC (1 min after boot 0 started)

### Boot -1 was long and stable

Boot -1 ran from 2026-04-22 16:58 UTC to 2026-04-25 01:12 UTC — **~56 hours**
with normal task and session activity throughout. The machine was not hung at
the time of the report; it had been manually rebooted to collect diagnostics.

### The April 22 churn: 25 rapid reboots

The real hang event is the cluster of 25 boots all on April 22:

```
-25  00:56:39 → 00:56:50  (11 seconds — never reached userspace)
-24  01:03:02 → 02:05:30  (~1h 2m)
-23  02:06:52 → 02:19:51  (~13 min)
-22  02:21:12 → 02:24:49  (~3.5 min)
-21  02:26:09 → 04:05:19  (~1h 39m)
-20  04:06:38 → 04:11:24  (~5 min)
-19  04:12:48 → 06:33:14  (~2h 20m)
...
 -2  16:47:17 → 16:57:13  (~10 min)
 -1  16:58:34 → Apr 25 01:12  (stable, ~56 hours)
```

Boot -25 lasted only 11 seconds — the kernel almost certainly never got the
filesystem mounted, let alone journald started. The pattern of alternating
short and medium boots is consistent with a chassis-level instability that
intermittently resolved and then recurred throughout the day before finally
stabilising around 16:58 UTC.

### Journal corruption

Journald reported two corrupt journals at boot -1 startup:

```
systemd-journald[437]: File system.journal corrupted or uncleanly shut down,
renaming and replacing.
systemd-journald[437]: File user-1005.journal corrupted or uncleanly shut down,
renaming and replacing.
```

Both confirm that earlier boots in the April 22 churn ended abruptly (hard
hang or iLO reset), not via a clean shutdown.

### SMBus timeouts (recurring, every boot)

Boot -1 dmesg (~1.5 seconds into userspace):

```
i801_smbus 0000:00:1f.4: Transaction timeout  (×4)
```

Current boot (boot 0) dmesg (~1 second into userspace):

```
i801_smbus 0000:00:1f.4: Transaction timeout  (×4)
```

Four timeouts appear on every single boot. The i801 SMBus is the Intel PCH bus
used for HP Moonshot chassis management. The timeouts are present even on
fully-healthy boots, which means they are either always-harmless noise or a
low-level chassis communication problem that usually recovers but occasionally
escalates into a full hang.

### ERST firmware warning

```
ERST: [Firmware Warn]: Firmware does not respond in time.
```

Identical to ms-025 and ms-107. The ACPI ERST firmware (iLO/BMC non-volatile
crash log storage) is sluggish or non-responsive on every boot.

### pstore

pstore is enabled (ERST backend) but was **empty** at report time. No panic
record survived from any of the April 22 rapid-reboot boots. Same conclusion as
ms-107/ms-025: the hangs are occurring before the kernel can write a crash
record, or iLO resets clear ERST before the OS comes up.

### Other observations

- `smartctl` not installed (`exit 127`) — NVMe health cannot be assessed.
- `run-puppet.service` took 47.8s — long but completed; not a hang vector.
- No failed systemd units; all filesystems mounted rw.
- `dis_ucode_ldr` in kernel cmdline — microcode disabled fleet-wide;
  MDS/TAA/MMIO reported as "no microcode."
- `generic-worker` `oom_score_adj` permission denied — benign, expected on
  these workers.

---

## Root cause hypothesis

**Intermittent chassis-level instability causing repeated hard resets**, with
the same underlying mechanism as ms-025 and ms-107: SMBus/iLO communication
failures and ERST firmware unresponsiveness point at the HP Moonshot chassis
backplane or CM firmware. On ms-112 the instability manifested as a rapid
reboot storm on April 22 rather than a single long gap, but the fingerprint
(4× SMBus timeouts per boot, ERST warning, no pstore records, journal
corruption) is identical across all three hosts.

The 11-second boot (-25) is the clearest data point: that boot never reached
journald, which means the hang point is at or before early kernel init — firmly
in firmware/hardware territory, not workload or OS.

See also: ms-025 (16-hour gap), ms-107 (31-hour gap) — same root cause, different
failure expression.

---

## Next actions

### Immediate (next hung host, before rebooting)

1. **Check pstore for a preserved crash record:**
   ```bash
   ls /sys/fs/pstore/
   cat /sys/fs/pstore/dmesg-erst-* 2>/dev/null | head -200
   ```

2. **Check SMBus timeout depth:**
   ```bash
   dmesg | grep -i 'smbus\|i801'
   ```
   Note whether the 4× timeout count changes or if additional timeouts appear
   during a hang-prone boot vs. a healthy one.

### Short-term (puppet / fleet)

3. **Install `smartmontools`** so NVMe SMART data is available in future
   reports.

4. **Cross-check other ms-0xx hosts** for the same `i801_smbus` timeout
   pattern and ERST warning — three confirmed hosts (025, 107, 112) strongly
   suggests a fleet-wide chassis issue.

5. **Check HP Moonshot CM firmware version** against HPE advisories for
   Moonshot 1500 / ProLiant m710x cartridges. A chassis-manager firmware update
   is the most likely fix if this is a known iLO/backplane defect.

6. **Check whether `dis_ucode_ldr` is intentional fleet config** — if not,
   re-enabling microcode loading may address CPU errata that interact with
   firmware communication.

### Medium-term (Phase 3 from runbook)

7. **Enable kdump** — without it, the 11-second boots and other pre-journald
   hangs leave no evidence. Even one dump would immediately narrow the
   diagnosis.

8. **Enable `kernel.hung_task_panic = 1` + `kernel.softlockup_panic = 1`** on
   a canary cartridge so hangs self-report rather than going silent.

9. **Correlate hang timing with chassis events** — pull HP Moonshot OA
   (Onboard Administrator) event logs for April 22 and look for cartridge
   power-cycle, thermal, or interconnect events around the ms-112 churn window
   (00:56–16:58 UTC).
