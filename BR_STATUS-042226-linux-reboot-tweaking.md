# Branch Status: `042226-linux-reboot-tweaking`

## Problem

`reboot --force` was added in 2020 (bug 1501936) to work around a systemd hang
during reboot on Ubuntu 18.04. On **24.04 workers with kernel 6.8.0+**,
`--force` bypasses systemd's orderly shutdown sequence, which appears to cause
silent hangs during driver teardown (suspected: `mlx4_en` NIC driver or NVMe).
This may be a contributing factor to the ms-025 class of "host reboots normally
but never comes back" hangs.

## Hypothesis

`reboot --force` tells systemd to shut down immediately without notifying
running services or waiting for device drivers to clean up. On 18.04 this was
necessary to escape a systemd deadlock; on 24.04 + 6.8.0+ the deadlock is gone
but `--force` now prevents NVMe/NIC drivers from flushing state, occasionally
leaving the hardware in a bad state that prevents the next boot from completing.

## Fix

Make the reboot command conditional on OS version:

**File:** `modules/linux_generic_worker/manifests/init.pp`

```puppet
$reboot_command = $facts['os']['release']['full'] ? {
  '24.04'  => '/usr/bin/sudo /sbin/reboot',
  default  => '/usr/bin/sudo /sbin/reboot --force',
}
```

24.04 workers use a graceful reboot; 18.04 keeps `--force` (still needed).

### Commit history

| Commit | Description |
|--------|-------------|
| `0d75629f` | Remove `reboot --force` on 24.04, keep on 18.04 |

## Verification

```bash
# Confirm the reboot script uses graceful reboot on 24.04 (no --force)
grep reboot /usr/local/bin/run-start-worker.sh

# After a full task cycle:
# - Worker picks up task, completes it, issues graceful reboot
# - Host comes back up cleanly within ~2-3 minutes
# - No silent-gap entries in boot list
journalctl --list-boots | head -20
```

## Status

| Version | Deployed | Watching | Result |
|---------|----------|----------|--------|
| 24.04   | Yes      | Yes      | Watching — deployed 2026-04-24 |
| 18.04   | N/A (unchanged) | — | — |

## Open questions

- Does graceful reboot on 24.04 actually eliminate the silent boot-hang?
  The ms-025 16-hour gap may have a second cause (SMBus/firmware — see
  `linux_moonshot_ms025_hang_analysis.md`). This fix addresses one vector
  but may not be the whole story.
- How long to soak before confident? Suggest 7 days without a silent-gap
  hang on a canary 24.04 host.

## Related analysis

- `linux_moonshot_ms025_hang_analysis.md` — ms-025 boot hang details
- `BR_STATUS-2404_ignore_secondary_interface.md` — related NM fix (separate vector)
