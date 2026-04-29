#!/usr/bin/env python3
"""Collect hang-diagnostic reports from hung/rebooted t-linux64-ms-* cartridges.

Usage:
  collect_moonshot_hang_reports.py [--auto] [--no-reset] [--no-freshness] [--ignore-recency] [HOST ...]

  --auto                    Fetch bad-host list from fleetroll instead of reading argv/stdin (requires --confirm).
  --no-reset                Skip iLO reboot (host already freshly rebooted).
  --freshness-requirement   Max acceptable age of fleetroll data in minutes (default: loop-interval).
  --ignore-recency          Process hosts even if collected within the last RECENCY_MINUTES minutes.
  HOST ...                  Short (ms025) or FQDN. If omitted and not --auto, reads stdin.
"""

import argparse
import datetime
import json
import re
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

FLEETROLL_DIR = Path.home() / "git/fleetroll_mvp"
RESET_DIR = Path.home() / "git/relops-infra/moonshot"
SCRIPT_DIR = Path(__file__).parent.resolve()
RESULTS_BASE = SCRIPT_DIR.parent / "moonshot_debugging_results"
HANG_SCRIPT = SCRIPT_DIR / "moonshot_hang_report.py"
RECENCY_MINUTES = 60
AUTO_BATCH_SIZE = 10
SCRIPT_VOICE_NAME = "Moonshot Medic"
STATE_FILE = RESULTS_BASE / "state.json"
OVERVIEW_FILE = RESULTS_BASE / "OVERVIEW.md"
OVERVIEW_HTML_FILE = RESULTS_BASE / "OVERVIEW.html"
SKIP_THRESHOLD_CONSECUTIVE = 3
SKIP_DURATION_HOURS = 6
FRESHNESS_MIN_PCT = 65

SSH_OPTS = [
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ConnectTimeout=30",
    "-o", "ServerAliveInterval=15",
    "-o", "ServerAliveCountMax=4",
]

# --- interrupt handling ---

_interrupt_count = 0


def _sigint_handler(sig, frame):
    global _interrupt_count
    _interrupt_count += 1
    if _interrupt_count == 1:
        print("\n[Ctrl-C] Will stop after current host finishes. Press again to exit immediately.",
              file=sys.stderr)
    else:
        print("\n[Ctrl-C] Exiting immediately.", file=sys.stderr)
        sys.exit(130)


# --- color / logging ---

_use_color = sys.stdout.isatty()
_log_fh = None


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _use_color else text


def _emit(line: str, *, stderr: bool = False) -> None:
    print(line, file=sys.stderr if stderr else sys.stdout)
    if _log_fh:
        print(re.sub(r'\033\[[0-9;]*m', '', line), file=_log_fh)


def info(msg: str) -> None:
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    _emit(f"{_c('2', ts)} {_c('1;34', '==>')} {_c('1', msg)}")


def section(msg: str) -> None:
    _emit(f"{_c('1;36', f'--- {msg} ---')}")


def ok(msg: str) -> None:
    _emit(f"{_c('1;32', '[OK]')} {msg}")


def warn(msg: str) -> None:
    _emit(f"{_c('1;33', '[WARN]')} {msg}")


def err(msg: str) -> None:
    _emit(f"{_c('1;31', '[ERROR]')} {msg}", stderr=True)


# --- hostname helpers ---

def worker_fqdn(hostname: str) -> str:
    """Convert any ms hostname form to its full FQDN."""
    if "." in hostname:
        return hostname
    matches = re.findall(r'\d+', hostname)
    if not matches:
        return hostname
    slot_str = matches[-1]
    i = int(slot_str.lstrip("0") or "0")
    prefix = hostname[: hostname.rfind(slot_str)]
    if prefix.lower().rstrip("-") in ("", "ms"):
        prefix = "t-linux64-ms-"
    if i > 630:
        c = ((i - 1) - 30) // 45 + 2
    elif i > 615:
        # Slots 616-630: 15-slot extension block that wraps back to chassis 1 (mdc1).
        # This reflects a specific DC layout exception; update if physical layout changes.
        c = ((i - 1) - 15) // 45 + 1 - 13
    elif i > 300:
        c = ((i - 1) + 15) // 45 + 1
    else:
        c = (i - 1) // 45 + 1
    dc = "mdc2" if c > 7 else "mdc1"
    return f"{prefix}{slot_str.zfill(3)}.test.releng.{dc}.mozilla.com"


def short_label(hostname: str) -> str:
    """Return a short ms label, e.g. 'ms025', from any hostname form."""
    base = hostname.split(".")[0]
    m = re.search(r'ms-?(\d+)$', base, re.IGNORECASE)
    if m:
        return f"ms{int(m.group(1)):03d}"
    return base


# --- SSH probe ---

def ssh_is_online(fqdn: str, timeout: int = 10) -> bool:
    try:
        sock = socket.create_connection((fqdn, 22), timeout=timeout)
        sock.close()
        return True
    except (socket.timeout, OSError):
        return False


# --- persistent host state ---

def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except Exception as exc:
            warn(f"Could not parse {STATE_FILE}: {exc} — starting with empty state")
            return {"hosts": {}}
    return {"hosts": {}}


def save_state(state: dict) -> None:
    RESULTS_BASE.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2) + "\n")
    tmp.replace(STATE_FILE)


def _host_entry(state: dict, fqdn: str) -> dict:
    return state["hosts"].setdefault(fqdn, {
        "consecutive_reset_failures": 0,
        "last_success": None,
        "last_failure": None,
        "total_resets": 0,
        "total_failures": 0,
        "skip_until": None,
    })


def record_reset_success(state: dict, fqdn: str) -> None:
    h = _host_entry(state, fqdn)
    h["consecutive_reset_failures"] = 0
    h["last_success"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    h["total_resets"] = h.get("total_resets", 0) + 1
    h["skip_until"] = None


def record_reset_failure(state: dict, fqdn: str) -> None:
    h = _host_entry(state, fqdn)
    h["consecutive_reset_failures"] = h.get("consecutive_reset_failures", 0) + 1
    h["last_failure"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    h["total_failures"] = h.get("total_failures", 0) + 1
    if h["consecutive_reset_failures"] >= SKIP_THRESHOLD_CONSECUTIVE:
        skip_until = (
            datetime.datetime.now(datetime.timezone.utc)
            + datetime.timedelta(hours=SKIP_DURATION_HOURS)
        ).isoformat()
        h["skip_until"] = skip_until
        label = short_label(fqdn)
        err(f"[{label}] {h['consecutive_reset_failures']} consecutive reset failures — "
            f"skipping for {SKIP_DURATION_HOURS}h (until {skip_until[:16]}Z)")


def is_skipped(state: dict, fqdn: str) -> bool:
    h = state["hosts"].get(fqdn, {})
    skip_until = h.get("skip_until")
    if not skip_until:
        return False
    return datetime.datetime.fromisoformat(skip_until) > datetime.datetime.now(datetime.timezone.utc)


def update_overview_md(state: dict) -> None:
    now = datetime.datetime.now(datetime.timezone.utc)
    hosts = state.get("hosts", {})

    def fmt(s: str | None) -> str:
        return s[:19].replace("T", " ") + " UTC" if s else ""

    lines = [
        "# Moonshot Auto-Reset Overview",
        "",
        "> **This file is auto-generated by `collect_moonshot_hang_reports.py`. Do not edit — changes will be overwritten.**",
        "",
        f"_Generated: {now.strftime('%Y-%m-%d %H:%M:%S UTC')}_",
        "",
    ]

    skipped = {
        fqdn: h for fqdn, h in hosts.items()
        if h.get("skip_until") and
        datetime.datetime.fromisoformat(h["skip_until"]) > now
    }
    counts = daily_counts()
    if counts:
        lines += ["## Daily Activity", ""]
        for date_str, count in counts:
            lines.append(f"- {date_str}: {count} host{'s' if count != 1 else ''}")
        lines.append("")

    if skipped:
        lines += ["## Needs Human Attention (currently skipped)", ""]
        for fqdn, h in sorted(skipped.items()):
            label = short_label(fqdn)
            lines.append(
                f"- **{label}** (`{fqdn}`): {h['consecutive_reset_failures']} consecutive failures, "
                f"skip until {fmt(h.get('skip_until'))}, "
                f"last failure: {fmt(h.get('last_failure'))}"
            )
        lines.append("")

    if hosts:
        lines += [
            "## Host History",
            "",
            "| Host | Total Resets | Failures | Consec Fails | Last Success | Last Failure | Skip Until |",
            "|------|-------------|----------|--------------|-------------|--------------|------------|",
        ]
        for fqdn, h in sorted(hosts.items()):
            label = short_label(fqdn)
            lines.append(
                f"| {label} | {h.get('total_resets', 0)} | {h.get('total_failures', 0)} | "
                f"{h.get('consecutive_reset_failures', 0)} | {fmt(h.get('last_success'))} | "
                f"{fmt(h.get('last_failure'))} | {fmt(h.get('skip_until'))} |"
            )
        lines.append("")

    RESULTS_BASE.mkdir(parents=True, exist_ok=True)
    OVERVIEW_FILE.write_text("\n".join(lines) + "\n")


def update_overview_html(state: dict) -> None:
    now = datetime.datetime.now(datetime.timezone.utc)
    hosts = state.get("hosts", {})

    def fmt(s: str | None) -> str:
        return s[:19].replace("T", " ") + " UTC" if s else ""

    skipped = {
        fqdn: h for fqdn, h in hosts.items()
        if h.get("skip_until") and
        datetime.datetime.fromisoformat(h["skip_until"]) > now
    }

    parts = [
        "<!DOCTYPE html>",
        '<html lang="en">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta http-equiv="refresh" content="60">',
        "<title>Moonshot Auto-Reset Overview</title>",
        "<style>",
        "  body { font-family: monospace; background: #111; color: #ccc; padding: 1.5rem; }",
        "  h1 { color: #fff; }",
        "  h2 { color: #f90; margin-top: 2rem; }",
        "  .generated { color: #666; font-size: .85em; margin-bottom: 1.5rem; }",
        "  table { border-collapse: collapse; width: 100%; }",
        "  th { background: #222; color: #aaa; text-align: left; padding: .4rem .8rem; border-bottom: 1px solid #444; }",
        "  td { padding: .35rem .8rem; border-bottom: 1px solid #2a2a2a; }",
        "  tr:hover td { background: #1a1a1a; }",
        "  .skip { background: #2a1a00; }",
        "  .skip td { color: #f90; }",
        "  .ok { color: #4c4; }",
        "  .bad { color: #f44; }",
        "  .warn { color: #f90; }",
        "</style>",
        "</head>",
        "<body>",
        "<h1>Moonshot Auto-Reset Overview</h1>",
        f'<p class="generated">Generated: {now.strftime("%Y-%m-%d %H:%M:%S UTC")}</p>',
    ]

    counts = daily_counts()
    if counts:
        parts.append("<h2>Daily Activity</h2>")
        parts.append("<table>")
        parts.append("  <thead><tr><th>Date</th><th>Hosts collected</th></tr></thead>")
        parts.append("  <tbody>")
        for date_str, count in counts:
            parts.append(f'  <tr><td>{date_str}</td><td class="ok">{count}</td></tr>')
        parts += ["  </tbody>", "</table>"]

    if skipped:
        parts.append('<h2>&#x26A0; Needs Human Attention (currently skipped)</h2>')
        parts.append("<ul>")
        for fqdn, h in sorted(skipped.items()):
            label = short_label(fqdn)
            parts.append(
                f'  <li class="bad"><strong>{label}</strong> ({fqdn}): '
                f'{h["consecutive_reset_failures"]} consecutive failures, '
                f'skip until {fmt(h.get("skip_until"))}, '
                f'last failure: {fmt(h.get("last_failure"))}</li>'
            )
        parts.append("</ul>")

    if hosts:
        parts += [
            "<h2>Host History</h2>",
            "<table>",
            "  <thead><tr>",
            "    <th>Host</th><th>Total Resets</th><th>Failures</th>"
            "<th>Consec Fails</th><th>Last Success</th><th>Last Failure</th><th>Skip Until</th>",
            "  </tr></thead>",
            "  <tbody>",
        ]
        for fqdn, h in sorted(hosts.items()):
            label = short_label(fqdn)
            is_skip = fqdn in skipped
            consec = h.get("consecutive_reset_failures", 0)
            row_class = ' class="skip"' if is_skip else ""
            consec_class = ' class="bad"' if consec >= SKIP_THRESHOLD_CONSECUTIVE else (' class="warn"' if consec > 0 else ' class="ok"')
            parts.append(
                f'  <tr{row_class}>'
                f"<td>{label}</td>"
                f'<td class="ok">{h.get("total_resets", 0)}</td>'
                f'<td>{h.get("total_failures", 0)}</td>'
                f"<td{consec_class}>{consec}</td>"
                f"<td>{fmt(h.get('last_success'))}</td>"
                f"<td>{fmt(h.get('last_failure'))}</td>"
                f"<td>{fmt(h.get('skip_until'))}</td>"
                f"</tr>"
            )
        parts += ["  </tbody>", "</table>"]

    parts += ["</body>", "</html>", ""]

    RESULTS_BASE.mkdir(parents=True, exist_ok=True)
    OVERVIEW_HTML_FILE.write_text("\n".join(parts))


# --- daily activity ---

def daily_counts() -> list[tuple[str, int]]:
    """Return (date_str, count) pairs sorted newest-first by scanning results dirs."""
    if not RESULTS_BASE.exists():
        return []
    results = []
    for d in sorted(RESULTS_BASE.iterdir(), reverse=True):
        if d.is_dir() and re.fullmatch(r'\d{8}', d.name):
            count = sum(1 for f in d.iterdir() if f.suffix == '.md')
            if count:
                date_str = f"{d.name[:4]}-{d.name[4:6]}-{d.name[6:]}"
                results.append((date_str, count))
    return results


# --- recency filter ---

def recently_processed(label: str) -> bool:
    if not RESULTS_BASE.exists():
        return False
    cutoff = datetime.datetime.now().timestamp() - RECENCY_MINUTES * 60
    return any(f.stat().st_mtime > cutoff for f in RESULTS_BASE.rglob(f"????????T??????Z-{label}.md"))


# --- announcements ---

_voice_enabled = True
_voice_all_hours = False
VOICE_HOUR_START = 10
VOICE_HOUR_END = 18


def say(msg: str) -> None:
    if not _voice_enabled:
        return
    if not _voice_all_hours and not (VOICE_HOUR_START <= datetime.datetime.now().hour < VOICE_HOUR_END):
        return
    subprocess.run(["say", "-v", "Rocko", "-r", "220", msg], check=False)


# --- subprocess helpers ---

def run(cmd: list, *, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, check=check)


def capture(cmd: list, *, cwd: Path | None = None, check: bool = True) -> str:
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)
    return (result.stdout + result.stderr).strip()


# --- per-host collection ---

def collect_host(fqdn: str, label: str, out_file: Path) -> bool:
    section(f"{label}  {fqdn}")
    host_ok = True
    tmp_file = out_file.with_suffix(".tmp")

    if run(["scp"] + SSH_OPTS + [str(HANG_SCRIPT), f"{fqdn}:/tmp/moonshot_hang_report.py"],
           check=False).returncode != 0:
        err(f"[{label}] scp upload failed")
        host_ok = False

    if host_ok:
        with tmp_file.open("w") as fh:
            result = subprocess.run(
                ["ssh"] + SSH_OPTS + [fqdn, "sudo python3 /tmp/moonshot_hang_report.py"],
                stdout=fh, check=False,
            )
        if result.returncode != 0:
            err(f"[{label}] remote script failed")
            tmp_file.unlink(missing_ok=True)
            host_ok = False

    # cleanup regardless of prior failures
    run(["ssh"] + SSH_OPTS + [fqdn, "rm -f /tmp/moonshot_hang_report.py"],
        check=False)

    if host_ok:
        section(f"{label}  host-audit")
        audit = capture(["uv", "run", "fleetroll", "host-audit", fqdn], cwd=FLEETROLL_DIR, check=False)
        with tmp_file.open("a") as f:
            f.write("\n---\n\n# Fleetroll Host Audit\n\n```\n")
            f.write(audit)
            f.write("\n```\n")
        tmp_file.rename(out_file)
        ok(f"[{label}] -> {out_file}")

    return host_ok


# --- main ---

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect hang-diagnostic reports from t-linux64-ms-* cartridges.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("hostname", nargs="*", metavar="HOST",
                        help="Short (ms025) or FQDN. Reads stdin if omitted.")
    parser.add_argument("--auto", action="store_true",
                        help="Fetch bad-host list from fleetroll.")
    parser.add_argument("-n", "--no-reset", action="store_true",
                        help="Skip iLO reboot.")
    parser.add_argument("--freshness-requirement", type=int, default=None, metavar="MINUTES",
                        help="Max acceptable age of fleetroll data in minutes (default: same as --loop-interval). "
                             "Set a large value to effectively disable the check.")
    parser.add_argument("--ignore-recency", action="store_true",
                        help=f"Process hosts even if collected within last {RECENCY_MINUTES} min.")
    parser.add_argument("--confirm", action="store_true",
                        help="Required with --auto to confirm you want to proceed.")
    parser.add_argument("-q", "--no-voice", action="store_true",
                        help="Suppress spoken announcements.")
    parser.add_argument("--voice-all-hours", action="store_true",
                        help=f"Speak outside working hours ({VOICE_HOUR_START}:00–before {VOICE_HOUR_END}:00).")
    parser.add_argument("-l", "--loop-interval", type=int, default=15, metavar="MINUTES",
                        help="Minutes to sleep between auto runs (default: 15).")
    return parser.parse_args()


def main() -> None:
    global _log_fh, _voice_enabled, _voice_all_hours

    args = parse_args()
    _voice_enabled = not args.no_voice
    _voice_all_hours = args.voice_all_hours

    if args.loop_interval < 1:
        err("--loop-interval must be at least 1 minute.")
        sys.exit(1)
    if args.freshness_requirement is not None and args.freshness_requirement < 1:
        err("--freshness-requirement must be at least 1 minute.")
        sys.exit(1)

    signal.signal(signal.SIGINT, _sigint_handler)

    print()
    print(_c('1;36', " ▄▀▄▀▄ ▄▀▄ ▄▀▄ ▄▀█ █▀ █░░ ▄▀▄ ▄█▄    ▄▀▄▀▄ ██▀ ▄▄█ ▀ ▄▀▀"))
    print(_c('1;36', " █░▀░█ ▀▄▀ ▀▄▀ █░█ ▄█ █▀█ ▀▄▀ ░█▄    █░▀░█ █▄▄ █▄█ █ ▀▄▄"))
    print()
    say(SCRIPT_VOICE_NAME)

    freshness_mins = args.freshness_requirement if args.freshness_requirement is not None else args.loop_interval
    freshness_label = (f"{freshness_mins}min"
                       if args.freshness_requirement is not None
                       else f"{freshness_mins}min (from loop interval)")

    if args.auto and not args.confirm:
        stale_threshold = freshness_mins * 60
        info(f"Checking fleetroll data freshness (max age: {freshness_label})...")
        r = subprocess.run(["uv", "run", "fleetroll", "data-freshness", "configs/host-lists/linux/all.list", "--stale-threshold", str(stale_threshold), "--min-fresh-pct", str(FRESHNESS_MIN_PCT)],
                           cwd=FLEETROLL_DIR, capture_output=True, text=True)
        freshness_out = (r.stdout + r.stderr).strip()
        for line in freshness_out.splitlines():
            _emit(f"  {_c('2', re.sub(r'^=+>\s*', '', line))}")
        if r.returncode != 0:
            err(f"Fleetroll data is stale (older than {stale_threshold}s). Refresh it before previewing.")
            sys.exit(1)
        info("Fetching bad-host list to preview run...")
        raw = capture(["bash", "tools/list_bad_linux_hosts.sh"], cwd=FLEETROLL_DIR, check=False)
        preview_hosts = raw.split() if raw else []
        n = min(len(preview_hosts), AUTO_BATCH_SIZE)
        print()
        if n:
            warn(f"Auto mode found {len(preview_hosts)} bad host(s); would process {n}:")
            warn(' '.join(preview_hosts[:n]))
        else:
            warn("Auto mode found no bad hosts to process.")
        print()
        warn("This is an automated script that will reboot hosts and collect diagnostics.")
        warn("You must watch and monitor the run. Re-run with --confirm to proceed.")
        sys.exit(1)

    # --- verify dependencies ---
    for d in (FLEETROLL_DIR, RESET_DIR):
        if not d.is_dir():
            err(f"Required directory not found: {d}")
            sys.exit(1)
    if not HANG_SCRIPT.is_file():
        err(f"Diagnostic script not found: {HANG_SCRIPT}")
        sys.exit(1)

    if RESULTS_BASE.exists():
        state = load_state()
        update_overview_md(state)
        update_overview_html(state)

    last_failed = False
    first_run = True

    while True:
        last_failed = False
        stale = False
        # --- freshness gate ---
        if args.auto:
            stale_threshold = freshness_mins * 60
            info(f"Checking fleetroll data freshness (max age: {freshness_label})...")
            r = subprocess.run(["uv", "run", "fleetroll", "data-freshness", "configs/host-lists/linux/all.list", "--stale-threshold", str(stale_threshold), "--min-fresh-pct", str(FRESHNESS_MIN_PCT)],
                               cwd=FLEETROLL_DIR, capture_output=True, text=True)
            freshness_out = (r.stdout + r.stderr).strip()
            for line in freshness_out.splitlines():
                _emit(f"  {_c('2', re.sub(r'^=+>\s*', '', line))}")
            if r.returncode != 0:
                print()
                warn(f"Fleetroll data is stale (older than {stale_threshold}s) — will retry next loop.")
                stale = True
                last_failed = True

        # --- resolve host list ---
        if not stale:
            if args.auto:
                info("Fetching bad-host list from fleetroll...")
                hosts = [worker_fqdn(h) for h in capture(["bash", "tools/list_bad_linux_hosts.sh"], cwd=FLEETROLL_DIR, check=False).split()]
            elif args.hostname:
                hosts = [worker_fqdn(h) for h in args.hostname]
            else:
                if sys.stdin.isatty():
                    print("Enter hostnames (one per line, Ctrl-D to finish):", file=sys.stderr)
                hosts = [worker_fqdn(line.strip()) for line in sys.stdin if line.strip()]

            if not hosts:
                warn("No bad hosts found." if args.auto else "No hosts specified. Nothing to do.")
                if not args.auto:
                    sys.exit(0)
            else:
                state = load_state()

                # --- recency + skip filter ---
                if not args.ignore_recency:
                    skipped, filtered = [], []
                    for h in hosts:
                        fqdn = worker_fqdn(h)
                        label = short_label(h)
                        if recently_processed(label):
                            skipped.append(h)
                        elif is_skipped(state, fqdn):
                            skip_until = state["hosts"].get(fqdn, {}).get("skip_until", "")
                            warn(f"Skipping {label}: {SKIP_THRESHOLD_CONSECUTIVE}+ consecutive reset failures "
                                 f"(skip until {skip_until[:16]}Z — use --ignore-recency to override)")
                            skipped.append(h)
                        else:
                            filtered.append(h)
                    if skipped:
                        warn(f"Skipping {len(skipped)} host(s): {' '.join(short_label(h) for h in skipped)}")
                    hosts = filtered

                if not hosts:
                    info("All requested hosts were recently processed. Nothing to do.")
                else:
                    batches = [hosts[i:i + AUTO_BATCH_SIZE] for i in range(0, len(hosts), AUTO_BATCH_SIZE)]
                    n_total = len(hosts)
                    info(f"Hosts to process: {n_total} host(s) across {len(batches)} batch(es) of up to {AUTO_BATCH_SIZE}")
                    say(f"Starting run. {n_total} host{'s' if n_total != 1 else ''} detected.")

                    if first_run:
                        first_run = False
                        warn("Starting in 15 seconds — press Ctrl-C to abort.")
                        for _ in range(15):
                            if _interrupt_count:
                                break
                            time.sleep(1)
                        if _interrupt_count:
                            warn("Aborted before first run.")
                            break

                    # --- create results dir and open log ---
                    run_dir = RESULTS_BASE / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d")
                    run_dir.mkdir(parents=True, exist_ok=True)
                    log_path = run_dir / "run.log"
                    info(f"Results will be saved to: {run_dir}")
                    info(f"Log: {log_path}")

                    _log_fh = log_path.open("a")
                    try:
                        _emit(f"Run started at {datetime.datetime.now(datetime.timezone.utc).isoformat()}")
                        _emit(f"Hosts: {' '.join(hosts)}")
                        _emit("")

                        if args.no_reset:
                            warn("Skipping reset (--no-reset).")

                        ok_hosts: list[str] = []
                        fail_hosts: list[str] = []

                        for batch_num, batch in enumerate(batches, 1):
                            if _interrupt_count:
                                warn("Stopping after interrupt.")
                                break

                            if len(batches) > 1:
                                section(f"Batch {batch_num}/{len(batches)}: {' '.join(short_label(h) for h in batch)}")

                            # --- reset batch ---
                            reset_fail_labels: list[str] = []
                            if not args.no_reset:
                                info("Resetting hosts via iLO (waiting for them to come back online)...")
                                run(["uv", "run", "./reset_moonshot.py", "--force"] + batch,
                                    cwd=RESET_DIR, check=False)
                                print()
                                online_hosts = []
                                for host in batch:
                                    fqdn = worker_fqdn(host)
                                    label = short_label(host)
                                    if ssh_is_online(fqdn):
                                        online_hosts.append(host)
                                        record_reset_success(state, fqdn)
                                    else:
                                        err(f"[{label}] did not come back online — skipping collection")
                                        record_reset_failure(state, fqdn)
                                        reset_fail_labels.append(label)
                                save_state(state)
                                update_overview_md(state)
                                update_overview_html(state)
                                batch = online_hosts

                            fail_hosts.extend(reset_fail_labels)

                            # --- collect batch ---
                            for host in batch:
                                fqdn = worker_fqdn(host)
                                label = short_label(host)
                                ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                                out_file = run_dir / f"{ts}-{label}.md"

                                try:
                                    if collect_host(fqdn, label, out_file):
                                        ok_hosts.append(label)
                                    else:
                                        err(f"[{label}] collection failed")
                                        fail_hosts.append(label)
                                except Exception as exc:
                                    err(f"[{label}] unexpected error: {exc}")
                                    fail_hosts.append(label)
                                print()

                                if _interrupt_count:
                                    warn("Stopping after interrupt.")
                                    break

                        # --- summary ---
                        _emit(_c('1', "=" * 40))
                        _emit(f"{_c('1', 'Run complete:')} {run_dir}")
                        if ok_hosts:
                            _emit(f"{_c('1;32', 'OK:  ')} {' '.join(ok_hosts)}")
                        if fail_hosts:
                            _emit(f"{_c('1;31', 'FAIL:')} {' '.join(fail_hosts)}")
                        _emit(_c('1', "=" * 40))

                        ok_n, fail_n = len(ok_hosts), len(fail_hosts)
                        if fail_n:
                            say(f"{ok_n} succeeded, {fail_n} failed.")
                        else:
                            say(f"All {ok_n} host{'s' if ok_n != 1 else ''} succeeded.")

                        last_failed = bool(fail_hosts)
                    finally:
                        if _log_fh:
                            _log_fh.close()
                            _log_fh = None

        if not args.auto or _interrupt_count:
            break

        info(f"Next run in {args.loop_interval} minute{'s' if args.loop_interval != 1 else ''}. "
             f"Press Ctrl-C to stop.")
        for _ in range(args.loop_interval * 60):
            if _interrupt_count:
                break
            time.sleep(1)

        if _interrupt_count:
            break

        print()

    sys.exit(1 if last_failed else 0)


if __name__ == "__main__":
    main()
