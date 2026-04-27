#!/usr/bin/env python3
"""Collect hang-diagnostic reports from hung/rebooted t-linux64-ms-* cartridges.

Usage:
  collect_moonshot_hang_reports.py [--auto] [--no-reset] [--no-freshness] [--ignore-recency] [HOST ...]

  --auto            Fetch bad-host list from fleetroll instead of reading argv/stdin (requires --confirm).
  --no-reset        Skip iLO reboot (host already freshly rebooted).
  --no-freshness    Skip fleetroll data-freshness check when using --auto.
  --ignore-recency  Process hosts even if collected within the last 60 minutes.
  HOST ...          Short (ms025) or FQDN. If omitted and not --auto, reads stdin.
"""

import argparse
import datetime
import re
import signal
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
    _emit(f"{_c('1;34', '==>')} {_c('1', msg)}")


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


# --- recency filter ---

def recently_processed(label: str) -> bool:
    if not RESULTS_BASE.exists():
        return False
    cutoff = datetime.datetime.now().timestamp() - RECENCY_MINUTES * 60
    return any(f.stat().st_mtime > cutoff for f in RESULTS_BASE.rglob(f"*-{label}.md"))


# --- announcements ---

_voice_enabled = True


def say(msg: str) -> None:
    if _voice_enabled:
        subprocess.run(["say", msg], check=False)


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

    if run(["scp"] + SSH_OPTS + [str(HANG_SCRIPT), f"{fqdn}:/tmp/moonshot_hang_report.py"],
           check=False).returncode != 0:
        err(f"[{label}] scp upload failed")
        host_ok = False

    if host_ok:
        with out_file.open("w") as fh:
            result = subprocess.run(
                ["ssh"] + SSH_OPTS + [fqdn, "sudo python3 /tmp/moonshot_hang_report.py"],
                stdout=fh, check=False,
            )
        if result.returncode != 0:
            err(f"[{label}] remote script failed")
            host_ok = False

    # cleanup regardless of prior failures
    run(["ssh"] + SSH_OPTS + [fqdn, "rm -f /tmp/moonshot_hang_report.py"],
        check=False)

    if host_ok:
        section(f"{label}  host-audit")
        audit = capture(["uv", "run", "fleetroll", "host-audit", fqdn], cwd=FLEETROLL_DIR, check=False)
        with out_file.open("a") as f:
            f.write("\n---\n\n# Fleetroll Host Audit\n\n```\n")
            f.write(audit)
            f.write("\n```\n")
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
    parser.add_argument("--no-reset", action="store_true",
                        help="Skip iLO reboot.")
    parser.add_argument("--no-freshness", action="store_true",
                        help="Skip fleetroll data-freshness check (with --auto).")
    parser.add_argument("--ignore-recency", action="store_true",
                        help=f"Process hosts even if collected within last {RECENCY_MINUTES} min.")
    parser.add_argument("--confirm", action="store_true",
                        help="Required with --auto to confirm you want to proceed.")
    parser.add_argument("--no-voice", action="store_true",
                        help="Suppress spoken announcements.")
    parser.add_argument("--loop-interval", type=int, default=15, metavar="MINUTES",
                        help="Minutes to sleep between auto runs (default: 15).")
    return parser.parse_args()


def main() -> None:
    global _log_fh, _voice_enabled

    args = parse_args()
    _voice_enabled = not args.no_voice

    if args.auto and not args.confirm:
        info("Fetching bad-host list to preview run...")
        raw = capture(["bash", "tools/list_bad_linux_hosts.sh"], cwd=FLEETROLL_DIR, check=False)
        preview_hosts = raw.split() if raw else []
        n = min(len(preview_hosts), AUTO_BATCH_SIZE)
        print()
        if n:
            warn(f"Auto mode would process {n} host(s) (of {len(preview_hosts)} found): "
                 f"{' '.join(preview_hosts[:n])}")
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

    signal.signal(signal.SIGINT, _sigint_handler)

    last_failed = False

    while True:
        # --- freshness gate ---
        if args.auto and not args.no_freshness:
            info("Checking fleetroll data freshness...")
            if run(["uv", "run", "fleetroll", "data-freshness"], cwd=FLEETROLL_DIR, check=False).returncode != 0:
                print()
                err("Fleetroll data is stale. Refresh it or pass --no-freshness to skip.")
                sys.exit(1)

        # --- resolve host list ---
        if args.auto:
            info("Fetching bad-host list from fleetroll...")
            hosts = capture(["bash", "tools/list_bad_linux_hosts.sh"], cwd=FLEETROLL_DIR).split()
        elif args.hostname:
            hosts = args.hostname
        else:
            if sys.stdin.isatty():
                print("Enter hostnames (one per line, Ctrl-D to finish):", file=sys.stderr)
            hosts = [line.strip() for line in sys.stdin if line.strip()]

        if not hosts:
            warn("No bad hosts found." if args.auto else "No hosts specified. Nothing to do.")
            if args.auto:
                say(f"{SCRIPT_VOICE_NAME}. No bad hosts. Rechecking in "
                    f"{args.loop_interval} minute{'s' if args.loop_interval != 1 else ''}.")
            else:
                sys.exit(0)
        else:
            # --- recency filter ---
            if not args.ignore_recency:
                skipped, filtered = [], []
                for h in hosts:
                    (skipped if recently_processed(short_label(h)) else filtered).append(h)
                if skipped:
                    warn(f"Skipping {len(skipped)} host(s) processed within last {RECENCY_MINUTES} min:"
                         f" {' '.join(skipped)}")
                    warn("(use --ignore-recency to override)")
                hosts = filtered

            if not hosts:
                info("All requested hosts were recently processed. Nothing to do.")
            else:
                if args.auto and len(hosts) > AUTO_BATCH_SIZE:
                    warn(f"Auto mode: capping at {AUTO_BATCH_SIZE} hosts ({len(hosts)} found).")
                    hosts = hosts[:AUTO_BATCH_SIZE]

                info(f"Hosts to process: {' '.join(hosts)}")
                n = len(hosts)
                say(f"{SCRIPT_VOICE_NAME}. Starting run. {n} host{'s' if n != 1 else ''} detected.")

                # --- create results dir and open log ---
                run_dir = RESULTS_BASE / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d")
                run_dir.mkdir(parents=True, exist_ok=True)
                log_path = run_dir / "run.log"
                info(f"Results will be saved to: {run_dir}")
                info(f"Log: {log_path}")

                _log_fh = log_path.open("a")
                _emit(f"Run started at {datetime.datetime.now(datetime.timezone.utc).isoformat()}")
                _emit(f"Hosts: {' '.join(hosts)}")
                _emit("")

                # --- reset ---
                if not args.no_reset:
                    info("Resetting hosts via iLO (waiting for them to come back online)...")
                    run(["uv", "run", "./reset_moonshot.py", "--force"] + hosts, cwd=RESET_DIR)
                    print()
                else:
                    warn("Skipping reset (--no-reset).")

                # --- collect reports ---
                ok_hosts: list[str] = []
                fail_hosts: list[str] = []

                for host in hosts:
                    fqdn = worker_fqdn(host)
                    label = short_label(host)
                    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                    out_file = run_dir / f"{ts}-{label}.md"

                    if collect_host(fqdn, label, out_file):
                        ok_hosts.append(label)
                    else:
                        err(f"[{label}] collection failed")
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
                    say(f"{SCRIPT_VOICE_NAME}. {ok_n} succeeded, {fail_n} failed.")
                else:
                    say(f"{SCRIPT_VOICE_NAME}. All {ok_n} host{'s' if ok_n != 1 else ''} succeeded.")

                last_failed = bool(fail_hosts)

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
