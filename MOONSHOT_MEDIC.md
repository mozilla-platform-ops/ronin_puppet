# Moonshot Medic

Moonshot Medic (`bin/moonshot_medic.py`) is an automated triage tool for hung
`t-linux64-ms-*` Moonshot cartridges in Mozilla's Firefox CI fleet. It sits
at the intersection of detection, remediation, and evidence collection: when
a cartridge stops accepting work, the tool resets it via iLO, collects a
hang diagnostic report while the system is freshly rebooted, and records the
outcome in persistent state so repeat offenders can be identified and escalated.

## Role in the Flakiness Investigation

The Moonshot fleet suffers from a class of intermittent hangs where cartridges
become unresponsive to Taskcluster — jobs queue up, workers go silent, and
human operators have to intervene manually. Moonshot Medic exists to remove
that toil and, more importantly, to build a body of evidence about *which*
machines hang, *how often*, and *what state they were in when they did*.

The loop is:

1. **Detect** — [fleetroll](https://github.com/mozilla-relops/fleetroll_mvp)
   identifies hosts that haven't reported a successful task recently. Medic
   polls fleetroll on a configurable interval (default 15 min) and fetches
   the current bad-host list.

2. **Gate** — Before acting, Medic checks that fleetroll's underlying data is
   fresh (≥65% of hosts have reported within the loop interval). Stale data
   means fleetroll itself may be broken, so the run is skipped rather than
   resetting hosts that might be fine.

3. **Reset** — Each bad host is cold-reset via iLO (`reset_moonshot.py`). Medic
   then waits for SSH port 22 to come back up to confirm the cartridge actually
   recovered. Hosts that don't come back are flagged as reset failures.

4. **Collect** — Once a host is back online, `moonshot_hang_report.py` is
   uploaded and executed remotely via SSH. It captures kernel logs, process
   state, memory pressure, and other hang indicators into a timestamped
   Markdown report saved under `moonshot_debugging_results/YYYYMMDD/`.
   A fleetroll host-audit is appended to the same file.

5. **Track** — Outcomes are persisted to `moonshot_debugging_results/state.json`.
   After 3 consecutive reset failures on the same host, Medic stops touching
   it for 6 hours and flags it in the overview as needing human attention.
   This prevents the tool from spinning on a truly broken cartridge.

6. **Report** — After each run, `OVERVIEW.md` and `OVERVIEW.html` are
   regenerated. The HTML report shows daily collection counts, hosts that need
   human attention, and full per-host reset history with sortable columns and
   a UTC/local time toggle.

## Usage

### One-shot (named hosts)

```
./bin/moonshot_medic.py ms025 ms107
```

Resets and collects from the named hosts. Short labels (`ms025`) or FQDNs both work.

### Automated loop

```
./bin/moonshot_medic.py --auto --loop-interval 30 --confirm
```

Polls fleetroll every 30 minutes and processes whatever bad hosts it finds.
`--confirm` is required as a safeguard against accidental automation.

### Skip reset (host already rebooted)

```
./bin/moonshot_medic.py --no-reset ms025
```

Skips the iLO reset and goes straight to collection. Useful when a host was
manually rebooted or just came back from maintenance.

### Key flags

| Flag | Default | Purpose |
|---|---|---|
| `--auto` | off | Pull bad-host list from fleetroll |
| `--loop-interval N` | 15 min | Sleep between auto runs |
| `--freshness-requirement N` | same as loop-interval | Max acceptable fleetroll data age |
| `--no-reset` / `-n` | off | Skip iLO reboot |
| `--ignore-recency` | off | Re-process hosts collected in the last 60 min |
| `--no-voice` / `-q` | off | Suppress macOS `say` announcements |
| `--voice-all-hours` | off | Speak outside 10:00–18:00 local time |

## Output

```
moonshot_debugging_results/
  state.json                    # Persistent per-host reset/failure history
  OVERVIEW.md                   # Human-readable summary table
  OVERVIEW.html                 # Sortable, interactive HTML report
  YYYYMMDD/
    run.log                     # Full timestamped log for the day's runs
    YYYYMMDDTHHMMSSz-ms025.md   # Per-host hang report + fleetroll audit
    ...
```

## Dependencies

Medic calls into two sibling repositories that must be checked out locally:

- `~/git/fleetroll_mvp` — provides `fleetroll data-freshness`, `fleetroll host-audit`,
  and `tools/list_bad_linux_hosts.sh`
- `~/git/relops-infra/moonshot` — provides `reset_moonshot.py` (iLO reboot logic)

SSH access to the cartridges is required, as is network access to the iLO
management interfaces.

## Agent Analysis Prompt

Paste the following into a Claude conversation after pointing it at the
`moonshot_debugging_results/` directory:

---

```
You are helping investigate intermittent hangs in Mozilla's Moonshot CI fleet —
a rack of HP Moonshot cartridges running t-linux64-ms-* Linux workers for
Firefox CI. The fleet has ~280 hosts across two datacenters (mdc1, mdc2).
Cartridges are physically grouped into chassis of 45 slots each; mdc1 holds
chassis 1–7, mdc2 holds chassis 8+. Host numbering encodes the chassis slot
(e.g. ms001–ms045 are chassis 1, ms046–ms090 are chassis 2, etc., with some
DC layout exceptions around ms300 and ms615–ms630).

When a cartridge hangs, it is cold-reset via iLO and a hang diagnostic report
is collected immediately after reboot. Reports are stored as Markdown files in
moonshot_debugging_results/YYYYMMDD/. Each file contains kernel logs, process
state, memory pressure metrics, and a fleetroll host audit. Persistent outcome
data (total resets, consecutive failures, skip status) lives in
moonshot_debugging_results/state.json.

Please read state.json and as many of the per-host report files as you need,
then produce a structured analysis covering:

1. **Repeat offenders** — Which hosts hang most frequently? Are any in a
   skip/escalation state? Is the failure rate accelerating or stable?

2. **Chassis and DC clustering** — Do failures cluster within specific chassis
   (groups of 45 adjacent host numbers)? Do mdc1 and mdc2 differ in failure
   rate? Clustering suggests shared hardware (power, cooling, fabric) as a
   cause.

3. **Reset failure vs hang pattern** — Distinguish hosts that hang but recover
   cleanly after a reset from hosts that fail to come back after reset at all.
   The latter likely have a hardware fault rather than a software hang.

4. **Diagnostic signal in the reports** — Scan the hang reports for common
   patterns: OOM/memory pressure events, kernel panics or BUG traces, hung
   task warnings, specific processes or services that are stuck, filesystem or
   storage errors, time-of-day or uptime correlations.

5. **Hypotheses** — Based on the above, propose ranked hypotheses for the root
   cause(s). Be specific: e.g. "chassis 3 may have a power or cooling issue",
   "hosts with >X GB memory pressure are more likely to hang", "the hang
   appears correlated with a specific kernel version or package".

6. **Recommended next steps** — What additional data would confirm or rule out
   the top hypothesis? Are there hosts that should be taken out of rotation for
   physical inspection? Are there Puppet/config changes worth trying fleet-wide?

Be concrete and data-driven. Cite specific host labels (e.g. ms025), chassis
numbers, dates, and report excerpts where relevant. If the data is insufficient
to support a conclusion, say so rather than speculating.
```
