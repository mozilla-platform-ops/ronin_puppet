# Branch Status: `2404_ignore_secondary_interface`

## Problem

HP Moonshot cartridges have two physical ports on the same NIC: `eno1` (primary,
has DHCP) and `eno1d1` (secondary, live cable but no DHCP scope). NetworkManager
attempts to manage both, causing two distinct failure modes:

- **24.04 hosts:** `NetworkManager-wait-online.service` blocks boot for ~90s
  waiting for a DHCP lease on `eno1d1` that never arrives.
- **18.04 hosts:** NM's DHCP retry loop on `eno1d1` corrupts DNS routing,
  causing `systemd-resolved` (127.0.0.53) to wedge. All DNS queries time out,
  generic-worker can't claim tasks, and Papertrail can't ship logs — the host
  appears "hung" for hours without actually being hung. (Confirmed on ms-179:
  45h+ DNS outage, no kernel panic, SSH remained reachable.)

## Fix

Drop an NM keyfile marking `eno1d1` unmanaged:

**File:** `/etc/NetworkManager/conf.d/unmanaged-devices.conf`
```
[keyfile]
unmanaged-devices=interface-name:eno1d1
```

**Puppet:** `modules/linux_gui/manifests/init.pp`

### Commit history

| Commit | Description |
|--------|-------------|
| `d6ad1056` | Original fix — `eno1d1` unmanaged rule, 24.04 only |
| `c9637f2f` | Extended rule to 18.04 + 22.04; added NM reload exec |

### What changed in `c9637f2f`

The original resource was inside the `'24.04':` case block. Moved it to the
Ubuntu-level scope (outside the version case) so all Ubuntu versions receive
the config. Added `exec { 'reload NetworkManager': refreshonly => true }` so
NM picks up the config immediately on first puppet apply rather than waiting
for the next reboot.

## Verification

```bash
# Confirm file landed and NM sees eno1d1 as unmanaged
cat /etc/NetworkManager/conf.d/unmanaged-devices.conf
nmcli device status | grep eno1d1   # should show: unmanaged

# After next reboot — NM-wait-online should drop from ~90s to <5s
systemd-analyze blame | grep NetworkManager-wait-online

# No DNS timeouts in journal
sudo journalctl -b 0 --no-pager | grep "i/o timeout"
```

## Status

| Version | Deployed | Watching | Result |
|---------|----------|----------|--------|
| 24.04   | Yes (`c9637f2f`) | Done | **Confirmed fixed** 2026-04-25: eno1d1 unmanaged, NM-wait-online ~170-180ms (was ~90s) on ms-018 and ms-019 |
| 18.04   | N/A | N/A | 18.04 uses server ISO — NM not installed/running. Fix is a no-op; DNS wedge on ms-179 may have had a different root cause. |
| 22.04   | No | — | Not yet |

## Related analysis

- `linux_moonshot_ms179_hang_analysis.md` — ms-179 (18.04) DNS wedge root cause
- `linux_moonshot_ms025_hang_analysis.md` — ms-025 (24.04) boot hang (separate issue)
