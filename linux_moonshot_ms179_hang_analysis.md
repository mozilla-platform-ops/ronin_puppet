# ms-179 Hang Analysis — 2026-04-23/24

## TL;DR

ms-179 did **not** hang at the hardware or kernel level. It suffered a complete
DNS failure that left it alive and SSH-able but unable to claim tasks or ship
logs. `generic-worker` was idle for 45+ hours because every DNS query to
`127.0.0.53:53` (systemd-resolved) returned `i/o timeout`. This is a different
failure class from ms-025.

---

## What the data shows

**Host:** `t-linux64-ms-179`
**OS:** Ubuntu 18.04, HP ProLiant m710x Server Cartridge (BIOS H07 02/26/2019)
**Pool:** `releng-hardware/gecko-t-linux-talos-1804`
**Report captured:** Apr 24 (after reboot at 16:14 UTC)

*Note: The report file starts mid-syslog.1 — the header sections (hostname,
uptime, kernel, reboot history) were cut off, likely by terminal scroll buffer
limits. The syslog.1 tail and subsequent sections are intact.*

### DNS completely broken in the previous boot

The entire visible window of `syslog.1` (Apr 23 20:24 – Apr 24 00:06) shows
the same error repeating on every `generic-worker` claim attempt:

```
dial tcp: lookup firefox-ci-tc.services.mozilla.com on 127.0.0.53:53:
    read udp 127.0.0.1:<port>->127.0.0.53:53: i/o timeout
```

`127.0.0.53` is `systemd-resolved`'s stub listener. Every single DNS query is
timing out — meaning systemd-resolved is up but cannot forward queries to the
upstream resolver. The host itself is alive and SSH-able; only DNS is broken.

### Consequences of the DNS failure

- **generic-worker idle 45h52m** (as of Apr 24 00:04:40). Back-calculating:
  the last task completed around **Apr 21 ~02:12 UTC**. The DNS failure appears
  to have started around that time or shortly after.
- **papertrail-syslog crash-looping continuously**: `restart counter at 1004`
  at the start of the log window, reaching `1129` by the end (~125 restarts in
  ~3.5 hours of visible log). Root cause: `Ncat: Could not resolve hostname
  "logs.papertrailapp.com"`. Because papertrail was down, **no off-box logs
  were being shipped** during the entire 45+ hour outage window. Papertrail is
  the only off-box log sink for 18.04 hosts.
- From fleetroll / TC's perspective the host appeared "unreachable" because it
  could not claim work, even though the kernel and SSH were fine.

### Host rebooted at Apr 24 16:14

The trigger for the reboot is not captured in this report (likely manual
intervention). The current boot (16:14) is what the diagnostic sections reflect.

### Current boot (Apr 24 16:14) — post-reboot state

**No SMBus timeouts** — unlike ms-025, this host shows no `i801_smbus` errors
in dmesg. Different chassis behaviour.

**No pstore crash records** — `/sys/fs/pstore/` exists but is empty. The
previous long idle boot did not end in a kernel panic.

**Four failed systemd units:**
```
● apt-news.service              failed
● esm-cache.service             failed
● networkd-dispatcher.service   failed   ← notable
● Xsession.service              failed
```
`networkd-dispatcher.service` failing is significant — this daemon handles
network state-change events and feeds changes to NetworkManager. Its failure
here could indicate the same underlying network/resolver issue is not fully
resolved after reboot.

**`run-puppet.service` took 53 seconds** — a slow puppet run at boot, possibly
because network was slow to come up (`NetworkManager-wait-online` took 6s).

**`v4l2loopback` kernel module taint:**
```
v4l2loopback: module verification failed: signature and/or required key missing - tainting kernel
```
The virtual video loopback module is unsigned and taints the kernel. Not
directly related to the hang, but worth noting — a tainted kernel makes crash
analysis harder.

**NVMe SMART unavailable** — `smartctl` not installed (same as ms-025).

---

## Root cause hypothesis

**systemd-resolved entered a broken state** in the previous boot, likely after
a network event (NIC link flap, DHCP lease issue, or NetworkManager
reconfiguration), and was not automatically recovered. On 18.04, systemd-resolved
can get stuck if it loses contact with the upstream nameserver and its internal
state machine doesn't re-probe. The fix is `systemctl restart systemd-resolved`
or a full reboot — neither happened automatically for 45+ hours.

The `networkd-dispatcher.service` failure in the current boot suggests the
underlying network configuration issue may be recurring.

---

## Comparison with ms-025

| | ms-025 | ms-179 |
|---|---|---|
| OS | 24.04 | 18.04 |
| Failure class | Boot hang (pre-journald) | DNS failure (app-layer) |
| SSH reachable? | No (hung) | Yes |
| Kernel panic? | Unknown (no pstore record) | No |
| DNS working? | Yes (after reboot) | No (during 45h window) |
| Hardware symptoms | SMBus timeouts | None |
| Papertrail logs during outage | Would have been shipped | Not shipped (DNS broken) |
| Trigger | Unknown — likely firmware/hardware | systemd-resolved wedge |

---

## Recommended next steps

### Immediate

1. **Verify DNS is working on ms-179 now**: `resolvectl status` or
   `dig firefox-ci-tc.services.mozilla.com`. If it's still broken after reboot,
   the network config itself is the problem, not just a resolver state glitch.

2. **Check what caused the DNS failure ~Apr 21 02:12** in Papertrail — but
   note that because papertrail was also down, there are likely no off-box logs
   from that window. Check the Moonshot chassis event log for NIC link events
   on ms-179 around that time.

3. **Investigate `networkd-dispatcher.service` failure** in the current boot:
   `journalctl -u networkd-dispatcher --no-pager` — this may be the same root
   cause recurring.

### Short-term (puppet / fleet)

4. **Add a DNS liveness monitor or watchdog** — if `systemd-resolved` is wedged,
   the host should self-heal (restart the resolver or reboot) rather than sitting
   idle for 45 hours. A simple cron or systemd timer that probes DNS and restarts
   `systemd-resolved` if it fails would have recovered this host automatically.

5. **Install `smartmontools`** fleet-wide (same gap as ms-025).

6. **Consider whether `networkd-dispatcher` should be running** on these
   18.04 hosts — if it's failing consistently it may indicate a configuration
   drift between what puppet applies and what the unit expects.

### For the investigation generally

7. **ms-179 is not contributing to the "hung cartridge" problem** in the
   same sense as ms-025. Its symptom (appears unreachable, fails to claim tasks)
   is the same from the outside, but the mechanism is entirely different. It
   should be tracked separately and not inflate the hardware hang count.
