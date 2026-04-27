#!/usr/bin/env python3
"""Collect Phase 1 hang-diagnostics from a t-linux64-ms-* cartridge.

Run as root (or with passwordless sudo) immediately after a reboot:
    sudo python3 bin/moonshot_hang_report.py -o /tmp/report.md
Then paste /tmp/report.md (or stdout) into your chat session.
"""

import argparse
import datetime
import subprocess
import sys
from dataclasses import dataclass, field
from typing import List, Optional

HANG_PATTERN = (
    r"hung task|soft lockup|call trace|oops|panic|bug:|oom-kill|invoked oom"
    r"|blocked for more than|i/o error|ext4-fs error|nvme|mpt|mce"
)


@dataclass
class Step:
    name: str
    cmd: str
    needs_sudo: bool = False
    # None = all OSes; "18.04" or "24.04" = only that version
    os_match: Optional[str] = None


def build_steps(boot: int) -> List[Step]:
    b = str(boot)  # e.g. "-1" for previous boot
    return [
        # --- header ---
        Step("hostname", "hostname"),
        Step("kernel + arch", "uname -a"),
        Step("os-release", "cat /etc/os-release"),
        Step("uptime", "uptime"),
        Step("date (UTC)", "date -u"),
        Step("last boot (who)", "who -b"),
        Step("reboot history", "last -x reboot | head -30"),
        # --- 18.04 steps ---
        Step(
            "syslog files",
            "ls -la /var/log/syslog* /var/log/kern.log* /var/log/dmesg* /var/log/auth.log*",
            needs_sudo=True,
            os_match="18.04",
        ),
        Step(
            "syslog grep (hang patterns)",
            f"zgrep -iE '{HANG_PATTERN}'"
            " /var/log/syslog.1 /var/log/kern.log.1"
            " /var/log/syslog.2.gz /var/log/kern.log.2.gz 2>/dev/null",
            needs_sudo=True,
            os_match="18.04",
        ),
        Step(
            "syslog.1 tail (2000 lines)",
            "tail -2000 /var/log/syslog.1",
            needs_sudo=True,
            os_match="18.04",
        ),
        Step(
            "journalctl kernel (current boot, 500 lines)",
            "journalctl -k --no-pager | tail -500",
            os_match="18.04",
        ),
        Step(
            "journalctl full (current boot, 2000 lines)",
            "journalctl --no-pager | tail -2000",
            os_match="18.04",
        ),
        # --- 24.04 steps ---
        Step(
            f"journalctl kernel (boot {b}, 500 lines)",
            f"journalctl -k -b {b} --no-pager | tail -500",
            os_match="24.04",
        ),
        Step(
            f"journalctl kernel grep (boot {b}, hang patterns)",
            f"journalctl -k -b {b} --no-pager | grep -iE '{HANG_PATTERN}'",
            os_match="24.04",
        ),
        Step(
            f"journalctl full (boot {b}, 2000 lines)",
            f"journalctl -b {b} --no-pager | tail -2000",
            os_match="24.04",
        ),
        Step(
            "boot list",
            "journalctl --list-boots | head -30",
            os_match="24.04",
        ),
        Step(
            f"OOM events (boot {b})",
            f"journalctl -b {b} --no-pager | grep -iE 'oom|killed process|out of memory'",
            os_match="24.04",
        ),
        # --- shared ---
        Step(
            "pstore crash records (survives across reboots)",
            "ls -la /sys/fs/pstore/ 2>/dev/null && cat /sys/fs/pstore/dmesg-erst-* 2>/dev/null || echo '(no pstore crash records)'",
            needs_sudo=True,
        ),
        Step(
            "crash / coredump dirs",
            "ls -la /var/crash/ /var/lib/systemd/coredump/ 2>/dev/null",
        ),
        Step(
            "SMBus / i801 timeouts (chassis management bus)",
            "dmesg -T | grep -iE 'smbus|i801'",
            needs_sudo=True,
        ),
        Step(
            "dmesg errors/failures/timeouts",
            "dmesg -T | grep -iE 'error|fail|reset|timeout'",
            needs_sudo=True,
        ),
        Step("dmesg ext4", "dmesg | grep -i ext4", needs_sudo=True),
        Step("mounts (check for ro)", "mount"),
        Step(
            "NVMe SMART (nvme0n1)",
            "smartctl -a /dev/nvme0n1 2>/dev/null || smartctl -a /dev/sda 2>/dev/null",
            needs_sudo=True,
        ),
        Step("systemd failed units", "systemctl --failed"),
        Step("systemd-analyze blame (top 20)", "systemd-analyze blame | head -20"),
    ]


def detect_os_version() -> str:
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("VERSION_ID="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "unknown"


def run_step(step: Step, use_sudo: bool, timeout: int) -> str:
    cmd = step.cmd
    if step.needs_sudo and use_sudo:
        cmd = "sudo -n " + cmd

    try:
        # shell=True is intentional: commands are hard-coded constants and use
        # shell pipelines (| grep, | tail, zgrep globs, etc.)
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = result.stdout
        if result.stderr:
            output += "\n[stderr]\n" + result.stderr
        if result.returncode not in (0, 1):  # 1 = grep found nothing
            output += f"\n[exit {result.returncode}]"
        return output.strip() or "(no output)"
    except subprocess.TimeoutExpired:
        return f"[timed out after {timeout}s]"
    except Exception as exc:  # noqa: BLE001
        return f"[error: {exc}]"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Collect Phase 1 hang diagnostics from a Moonshot cartridge."
    )
    parser.add_argument("-o", "--output", metavar="PATH", help="also write report to this file")
    parser.add_argument(
        "--no-sudo", action="store_true", help="skip commands that require root"
    )
    parser.add_argument(
        "--boot",
        type=int,
        default=-1,
        metavar="N",
        help="which boot to inspect on 24.04 (default: -1 = previous)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        metavar="SECS",
        help="per-command timeout in seconds (default: 30)",
    )
    args = parser.parse_args()

    os_version = detect_os_version()
    use_sudo = not args.no_sudo
    steps = build_steps(args.boot)

    lines: List[str] = []
    lines.append("# Moonshot Hang Report")
    lines.append(f"\nGenerated: {datetime.datetime.now(datetime.timezone.utc).isoformat()}")
    lines.append(f"OS version detected: `{os_version}`")
    lines.append(f"Boot target: `{args.boot}` (24.04 only)\n")
    lines.append("---\n")

    for step in steps:
        if step.os_match and step.os_match != os_version:
            continue
        if step.needs_sudo and not use_sudo:
            lines.append(f"## {step.name}")
            lines.append("\n```\n[skipped — requires sudo]\n```\n")
            continue

        output = run_step(step, use_sudo, args.timeout)
        lines.append(f"## {step.name}")
        lines.append(f"\n```\n{output}\n```\n")

    report = "\n".join(lines)

    sys.stdout.write(report + "\n")

    if args.output:
        with open(args.output, "w") as f:
            f.write(report + "\n")
        print(f"\n[report written to {args.output}]", file=sys.stderr)


if __name__ == "__main__":
    main()
