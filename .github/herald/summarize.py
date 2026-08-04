#!/usr/bin/env python3
"""Produce the ``ai_summary`` block for a Herald change event using Claude.

Reads a commit's diff and changed-file list, asks Claude (Sonnet 5 by default)
to describe the change, and emits the ``ai_summary`` object the event schema
expects (see schema/event.schema.json → ai_summary).

**The event must always flow.** Any failure — missing API key, network error,
rate limit, a model refusal, or malformed output — is caught and turned into an
error-shaped summary (``description: null``, ``error: "<why>"``) so Herald
renders a stub entry instead of dropping the change. That is exactly the
AI-failure path modeled in examples/event-example-ai-failure.json.

Auth: the Anthropic SDK reads ANTHROPIC_API_KEY from the environment.

Usage:
    python summarize.py --diff <patch-file> --files <changed-files-list>
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

DEFAULT_MODEL = "claude-sonnet-5"

# Bound the diff we send so a large refactor can't blow up cost/context.
MAX_DIFF_CHARS = 12_000

SYSTEM = (
    "You write concise changelog entries for Mozilla RelOps infrastructure. "
    "The source repo is ronin_puppet: Puppet manifests (roles, profiles, "
    "modules) and Hiera data (YAML). Given a commit and its diff, summarize "
    "what changed and why it matters operationally. Be factual and specific to "
    "the diff; do not speculate about intent you can't see. Prefer concrete "
    "nouns (role/module/package/setting names, version numbers) over vague "
    "phrasing."
)

# JSON schema for structured output. Note: JSON-schema maxLength is not
# supported by the API, so the 120-char headline cap is enforced by the prompt
# and clamped client-side below.
OUTPUT_SCHEMA = {
    "type": "object",
    "properties": {
        "description": {
            "type": "string",
            "description": "1-3 sentence Markdown summary of the change.",
        },
        "headline": {
            "type": "string",
            "description": "Short summary, at most 120 characters, no trailing period.",
        },
        "tags": {
            "type": "array",
            "items": {"type": "string"},
            "description": "0-5 lowercase labels, e.g. dependency-bump, security, hiera, config.",
        },
    },
    "required": ["description", "headline", "tags"],
    "additionalProperties": False,
}

HEADLINE_MAX = 120


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_diff(path: str | None) -> str:
    if not path or not os.path.exists(path):
        return ""
    text = open(path, encoding="utf-8", errors="replace").read()
    if len(text) > MAX_DIFF_CHARS:
        text = text[:MAX_DIFF_CHARS] + "\n\n[... diff truncated for length ...]"
    return text


def _read_files(path: str | None) -> list[str]:
    if not path or not os.path.exists(path):
        return []
    return [line.strip() for line in open(path, encoding="utf-8") if line.strip()]


def _build_prompt(subject: str, files: list[str], diff: str) -> str:
    file_list = "\n".join(f"- {f}" for f in files) or "(none listed)"
    diff_block = diff or "(diff unavailable)"
    return (
        f"Commit subject:\n{subject}\n\n"
        f"Changed files:\n{file_list}\n\n"
        f"Diff:\n```diff\n{diff_block}\n```\n\n"
        "Return description (1-3 sentences), headline (<=120 chars, no trailing "
        "period), and tags."
    )


def error_summary(message: str, model: str) -> dict:
    """AI-failure shape: description is null, error carries the reason."""
    return {
        "model": model,
        "generated_at": _now(),
        "description": None,
        "headline": None,
        "tags": [],
        "error": message,
    }


def generate_summary(subject: str, files: list[str], diff: str, model: str) -> dict:
    """Call Claude and return a success-shaped ai_summary. Raises on any failure."""
    import anthropic  # imported here so an install/import failure hits the error path

    client = anthropic.Anthropic()
    response = client.messages.create(
        model=model,
        max_tokens=1024,
        thinking={"type": "disabled"},  # a short summary needs no reasoning budget
        system=SYSTEM,
        messages=[{"role": "user", "content": _build_prompt(subject, files, diff)}],
        output_config={"format": {"type": "json_schema", "schema": OUTPUT_SCHEMA}},
    )

    if response.stop_reason == "refusal":
        detail = getattr(response.stop_details, "explanation", None) or "safety refusal"
        raise RuntimeError(f"model refused to summarize: {detail}")
    if response.stop_reason == "max_tokens":
        raise RuntimeError("summary truncated (max_tokens) — output not valid JSON")

    text = next((b.text for b in response.content if b.type == "text"), None)
    if not text:
        raise RuntimeError("no text block in response")

    data = json.loads(text)  # output_config guarantees valid JSON on success
    headline = (data.get("headline") or "").strip()
    if len(headline) > HEADLINE_MAX:
        headline = headline[: HEADLINE_MAX - 1].rstrip() + "…"

    return {
        "model": response.model,  # the model that actually served the request
        "generated_at": _now(),
        "description": data["description"],
        "headline": headline or None,
        "tags": data.get("tags") or [],
        "error": None,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--diff", help="Path to the commit diff/patch file.")
    parser.add_argument("--files", help="Path to a newline list of changed files.")
    args = parser.parse_args(argv)

    model = os.environ.get("MODEL", DEFAULT_MODEL)
    subject = os.environ.get("COMMIT_SUBJECT", "(no subject)")
    files = _read_files(args.files)
    diff = _read_diff(args.diff)

    try:
        summary = generate_summary(subject, files, diff, model)
    except Exception as exc:  # noqa: BLE001 — event must flow even on unexpected errors
        summary = error_summary(f"{type(exc).__name__}: {exc}", model)

    json.dump(summary, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
