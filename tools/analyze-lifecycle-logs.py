#!/usr/bin/env python3
"""Aggregate collected host-lifecycle JSONL snapshots."""

import argparse
import csv
import datetime
import gzip
import json
import math
import pathlib
import sys
from collections import defaultdict


REPORT_MEASUREMENTS = (
    "restart_to_boot",
    "early_host_startup",
    "puppet_run",
    "worker_initialization",
    "task_runtime",
    "post_task_overhead",
)


def event_timestamp(event):
    value = event.get("event_time", event.get("recorded_at"))
    if not isinstance(value, str):
        raise ValueError("event timestamp must be a string")
    return datetime.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()


def event_files(inputs):
    for input_path in inputs:
        path = pathlib.Path(input_path)
        if path.is_file():
            yield path
        elif path.is_dir():
            for candidate in sorted(path.rglob("events.jsonl*")):
                if candidate.is_file():
                    yield candidate


def load_events(inputs):
    """Load valid events from snapshots and deduplicate repeat transfers."""
    events = []
    seen = set()
    for path in event_files(inputs):
        opener = gzip.open if path.suffix == ".gz" else open
        with opener(path, "rt", encoding="utf-8", errors="replace") as event_log:
            for line in event_log:
                try:
                    event = json.loads(line)
                    key = (event["host_id"], event["event_id"])
                    event_timestamp(event)
                except (KeyError, TypeError, ValueError, json.JSONDecodeError):
                    continue
                if key not in seen:
                    seen.add(key)
                    events.append(event)
    return events


def nearest_rank(values, percentile):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(percentile * len(ordered)) - 1)]


def first_event(events, event_name):
    return next((event for event in events if event["event"] == event_name), None)


def add_duration(samples, measurement, host, start, end):
    if start is not None and end is not None and event_timestamp(end) >= event_timestamp(start):
        samples[measurement].append({"host": host, "seconds": event_timestamp(end) - event_timestamp(start)})


def aggregate(events):
    """Compute documented durations and describe incomplete observed boots."""
    by_host = defaultdict(list)
    for event in events:
        by_host[event["host_id"]].append(event)

    samples = defaultdict(list)
    incomplete = []
    for host, host_events in by_host.items():
        host_events.sort(key=event_timestamp)
        by_boot = defaultdict(list)
        for event in host_events:
            by_boot[event["boot_id"]].append(event)

        for boot_id, boot_events in by_boot.items():
            boot_events.sort(key=event_timestamp)
            boot = first_event(boot_events, "boot_started")
            puppet_started = first_event(boot_events, "puppet_run_started")
            puppet_succeeded = first_event(boot_events, "puppet_run_succeeded")
            worker_started = first_event(boot_events, "worker_started")
            worker_ready = first_event(boot_events, "worker_ready")
            restart = first_event(boot_events, "restart_executed")
            add_duration(samples, "early_host_startup", host, boot, puppet_started)
            add_duration(samples, "puppet_run", host, puppet_started, puppet_succeeded)
            add_duration(samples, "worker_initialization", host, worker_started, worker_ready)

            task_starts = {
                (event.get("task_id"), event.get("run_id")): event
                for event in boot_events
                if event["event"] == "task_started"
            }
            for finished in (event for event in boot_events if event["event"] == "task_finished"):
                started = task_starts.get((finished.get("task_id"), finished.get("run_id")))
                add_duration(samples, "task_runtime", host, started, finished)
                add_duration(samples, "post_task_overhead", host, finished, restart)
            for started in task_starts.values():
                add_duration(samples, "idle_claim_latency", host, worker_ready, started)

            if restart is None:
                incomplete.append(
                    {
                        "host": host,
                        "boot_id": boot_id,
                        "final_event": boot_events[-1]["event"],
                        "final_event_time": boot_events[-1].get("event_time", boot_events[-1]["recorded_at"]),
                    }
                )

        for restart in (event for event in host_events if event["event"] == "restart_executed"):
            next_boot = next(
                (
                    event
                    for event in host_events
                    if event["event"] == "boot_started"
                    and event["boot_id"] != restart["boot_id"]
                    and event_timestamp(event) >= event_timestamp(restart)
                ),
                None,
            )
            add_duration(samples, "restart_to_boot", host, restart, next_boot)
            if next_boot is not None:
                next_worker_started = next(
                    (
                        event
                        for event in host_events
                        if event["event"] == "worker_started"
                        and event["boot_id"] == next_boot["boot_id"]
                        and event_timestamp(event) >= event_timestamp(next_boot)
                    ),
                    None,
                )
                add_duration(samples, "restart_to_worker", host, restart, next_worker_started)
    return samples, incomplete


def percentile_rows(samples):
    rows = []
    for measurement in REPORT_MEASUREMENTS:
        values = samples[measurement]
        scopes = {"combined": [sample["seconds"] for sample in values]}
        for host in sorted({sample["host"] for sample in values}):
            scopes[host] = [sample["seconds"] for sample in values if sample["host"] == host]
        for scope, durations in scopes.items():
            if durations:
                rows.append(
                    {
                        "measurement": measurement,
                        "scope": scope,
                        "count": len(durations),
                        "p50_seconds": nearest_rank(durations, 0.50),
                        "p95_seconds": nearest_rank(durations, 0.95),
                        "max_seconds": max(durations),
                    }
                )
    return rows


def terminal_report(rows, incomplete):
    lines = ["measurement                 scope       count     p50     p95     max"]
    for row in rows:
        lines.append(
            "{:<27} {:<11} {:>5} {:>7.1f} {:>7.1f} {:>7.1f}".format(
                row["measurement"],
                row["scope"],
                row["count"],
                row["p50_seconds"],
                row["p95_seconds"],
                row["max_seconds"],
            )
        )
    lines.append("incomplete observed boots: {}".format(len(incomplete)))
    for item in incomplete:
        lines.append("  {host} {boot_id}: {final_event}".format(**item))
    return "\n".join(lines)


def parse_args(arguments):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", help="snapshot directories or event files")
    parser.add_argument("--format", choices=("terminal", "json", "csv"), default="terminal")
    return parser.parse_args(arguments)


def main(arguments=None):
    args = parse_args(arguments)
    samples, incomplete = aggregate(load_events(args.inputs))
    rows = percentile_rows(samples)
    if args.format == "terminal":
        print(terminal_report(rows, incomplete))
    elif args.format == "json":
        print(json.dumps({"percentiles": rows, "incomplete_lifecycles": incomplete}, indent=2))
    else:
        writer = csv.DictWriter(sys.stdout, fieldnames=("measurement", "scope", "count", "p50_seconds", "p95_seconds", "max_seconds"))
        writer.writeheader()
        writer.writerows(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
