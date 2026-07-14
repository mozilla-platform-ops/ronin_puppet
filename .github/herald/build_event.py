#!/usr/bin/env python3
"""Assemble a Herald change event from its parts.

Combines the entity list (from ``map_entities.py``), the AI summary (from
``summarize.py``), and commit metadata (from the environment) into a single
event object matching ``schema/event.schema.json``.

Environment variables (all required unless noted):
    SOURCE_REPO      e.g. "mozilla-platform-ops/ronin_puppet"
    COMMIT_SHA       full 40-char SHA
    COMMIT_URL       permalink to the commit
    ACTOR            GitHub login of the merger
    TIMESTAMP        RFC 3339 UTC, e.g. "2026-05-21T15:00:00Z"
    COMMIT_SUBJECT   first line of the commit message
    PR_NUMBER        optional; integer, or empty/"null" for direct pushes
    PR_URL           optional; permalink, or empty for direct pushes
"""

from __future__ import annotations

import json
import os
import sys


def _pr_number() -> int | None:
    raw = os.environ.get("PR_NUMBER", "").strip()
    if not raw or raw.lower() == "null":
        return None
    return int(raw)


def build_event(entities: list[dict], ai_summary: dict) -> dict:
    pr_number = _pr_number()
    pr_url = os.environ.get("PR_URL", "").strip() or None
    return {
        "schema_version": "1",
        "source_repo": os.environ["SOURCE_REPO"],
        "commit_sha": os.environ["COMMIT_SHA"],
        "commit_url": os.environ["COMMIT_URL"],
        "pr_number": pr_number,
        "pr_url": pr_url if pr_number is not None else None,
        "actor": os.environ["ACTOR"],
        "timestamp": os.environ["TIMESTAMP"],
        "commit_subject": os.environ["COMMIT_SUBJECT"],
        "ai_summary": ai_summary,
        "entities": entities,
    }


def main(argv: list[str]) -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--entities", required=True, help="entities JSON file")
    parser.add_argument("--ai", required=True, help="ai_summary JSON file")
    args = parser.parse_args(argv)

    entities = json.loads(open(args.entities, encoding="utf-8").read())
    ai_summary = json.loads(open(args.ai, encoding="utf-8").read())
    json.dump(build_event(entities, ai_summary), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
