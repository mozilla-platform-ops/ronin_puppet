#!/usr/bin/env python3
"""Produce the ``ai_summary`` block for a Herald change event.

**This is the one integration point that is intentionally a placeholder.** The
real reporter should call an AI agent here (the model that RelOps standardizes
on) to describe the diff. Until that is wired, this script emits a deterministic,
non-AI fallback so the reporter pipeline is runnable end-to-end.

Contract (from schema/event.schema.json → ai_summary):
  * exactly one of ``description`` / ``error`` is non-null
  * on success: description (Markdown), optional headline (<=120 chars), tags[]
  * on failure: error (non-empty string), description=null

Env:
  COMMIT_SUBJECT   first line of the commit message
  MODEL            model id to record (default "placeholder-0")
Args:
  file paths touched by the commit (for a trivial file-based description)
"""

from __future__ import annotations

import json
import os
import sys


def fallback_summary(subject: str, files: list[str]) -> dict:
    """A non-AI summary. Success-shaped so the change renders normally."""
    n = len(files)
    plural = "file" if n == 1 else "files"
    description = f"{subject}\n\nTouches {n} {plural}: " + ", ".join(
        f"`{f}`" for f in files[:10]
    )
    if n > 10:
        description += f", and {n - 10} more"
    description += "."
    headline = subject if len(subject) <= 120 else subject[:117] + "..."
    return {
        "model": os.environ.get("MODEL", "placeholder-0"),
        # generated_at is stamped by the caller (workflow) so this stays pure.
        "generated_at": os.environ["GENERATED_AT"],
        "description": description,
        "headline": headline,
        "tags": [],
        "error": None,
    }


def error_summary(message: str) -> dict:
    """Use this shape when a real AI call fails — the event still flows."""
    return {
        "model": os.environ.get("MODEL", "placeholder-0"),
        "generated_at": os.environ["GENERATED_AT"],
        "description": None,
        "headline": None,
        "tags": [],
        "error": message,
    }


def main(argv: list[str]) -> int:
    subject = os.environ.get("COMMIT_SUBJECT", "(no subject)")
    # TODO: replace fallback_summary(...) with a real AI call; on exception,
    # return error_summary(str(exc)) so the change is still recorded as a stub.
    summary = fallback_summary(subject, argv)
    json.dump(summary, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
