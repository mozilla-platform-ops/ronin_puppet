#!/usr/bin/env python3
"""Herald reporter helper: map ronin_puppet file paths to entities and assemble
the change-event JSON that conforms to event.schema.json.

Two subcommands:
  map-entities  reads a list of changed paths, writes entities.json
  assemble      combines entities + commit metadata + AI response into event.json
"""

import argparse
import json
import re
import sys
from pathlib import Path

import jsonschema

ROLE_RE = re.compile(r"^modules/roles_profiles/manifests/roles/([^/]+)\.pp$")
PROFILE_RE = re.compile(r"^modules/roles_profiles/manifests/profiles/([^/]+)\.pp$")
ROLE_HIERA_RE = re.compile(r"^data/roles/([^/]+)\.yaml$")
OS_DATA_RE = re.compile(r"^data/os/([^/]+)\.yaml$")
COMMON_DATA_RE = re.compile(r"^data/(common)\.yaml$")
MODULE_RE = re.compile(r"^modules/(?!roles_profiles/)([^/]+)/")

# Per proposal: staging/alpha images, pools, and roles are excluded from output.
STAGING_ALPHA_RE = re.compile(r"(_staging$|alpha)", re.IGNORECASE)

# Impact analysis: parse Puppet manifests to derive transitive role impact.
INCLUDE_PROFILE_RE = re.compile(
    r"\b(?:include|require)\s+(?:::)?roles_profiles::profiles::([A-Za-z0-9_]+)"
)
PROFILE_CLASS_RE = re.compile(
    r"class\s*\{\s*['\"](?:::)?roles_profiles::profiles::([A-Za-z0-9_]+)"
)
# Module reference inside a profile: include/require/class on a non-roles_profiles name.
MODULE_REF_RE = re.compile(
    r"\b(?:include|require)\s+(?:::)?([a-z][A-Za-z0-9_]*)(?:::[A-Za-z0-9_:]+)?"
)
MODULE_CLASS_RE = re.compile(
    r"class\s*\{\s*['\"](?:::)?([a-z][A-Za-z0-9_]*)(?:::[A-Za-z0-9_:]+)?['\"]"
)

# OS data file -> substring(s) in role names that indicate that OS family.
OS_TO_ROLE_HINTS = {
    "Darwin": ("mac", "osx", "darwin"),
    "Debian": ("linux",),
    "Windows": ("win",),
}


def map_files_to_entities(paths):
    entities = {}
    patterns = [
        (ROLE_RE, "role"),
        (PROFILE_RE, "profile"),
        (ROLE_HIERA_RE, "role-hiera"),
        (OS_DATA_RE, "os-data"),
        (COMMON_DATA_RE, "common-data"),
        (MODULE_RE, "module"),
    ]

    for raw in paths:
        path = raw.strip()
        if not path or path.startswith("r10k_modules/"):
            continue
        for regex, etype in patterns:
            m = regex.match(path)
            if not m:
                continue
            eid = m.group(1)
            if etype in ("role", "profile", "role-hiera") and STAGING_ALPHA_RE.search(eid):
                break
            entities.setdefault((etype, eid), set()).add(path)
            break

    return [
        {"type": etype, "id": eid, "files": sorted(files)}
        for (etype, eid), files in sorted(entities.items())
    ]


def index_role_manifests(repo_root):
    """Return {role_id: set(profile_ids)} parsed from modules/roles_profiles/manifests/roles/*.pp."""
    roles_dir = Path(repo_root) / "modules/roles_profiles/manifests/roles"
    out = {}
    if not roles_dir.is_dir():
        return out
    for pp in roles_dir.glob("*.pp"):
        role_id = pp.stem
        if STAGING_ALPHA_RE.search(role_id):
            continue
        text = pp.read_text(errors="replace")
        profiles = set(INCLUDE_PROFILE_RE.findall(text)) | set(PROFILE_CLASS_RE.findall(text))
        out[role_id] = profiles
    return out


def index_profile_manifests(repo_root):
    """Return {profile_id: set(module_ids)} parsed from .../profiles/*.pp.

    A module is any include/require/class target that isn't itself a profile.
    """
    profiles_dir = Path(repo_root) / "modules/roles_profiles/manifests/profiles"
    out = {}
    if not profiles_dir.is_dir():
        return out
    for pp in profiles_dir.glob("*.pp"):
        profile_id = pp.stem
        text = pp.read_text(errors="replace")
        refs = set(MODULE_REF_RE.findall(text)) | set(MODULE_CLASS_RE.findall(text))
        # Drop language keywords and profile self-references.
        refs.discard("roles_profiles")
        refs.discard("include")
        refs.discard("require")
        refs.discard("class")
        out[profile_id] = refs
    return out


def compute_impact(entities, repo_root):
    """Derive the set of affected roles from the touched entities.

    Returns {"worker_pools": [...], "azure_images": [...]} of role names (no
    staging/alpha; "azure" in name -> azure_images, otherwise worker_pools).
    """
    role_to_profiles = index_role_manifests(repo_root)
    profile_to_modules = index_profile_manifests(repo_root)

    # Reverse maps for fast lookup.
    profile_to_roles = {}
    for role, profs in role_to_profiles.items():
        for p in profs:
            profile_to_roles.setdefault(p, set()).add(role)

    module_to_profiles = {}
    for prof, mods in profile_to_modules.items():
        for m in mods:
            module_to_profiles.setdefault(m, set()).add(prof)

    affected = set()
    all_roles = set(role_to_profiles)

    for e in entities:
        etype, eid = e["type"], e["id"]
        if etype in ("role", "role-hiera"):
            if eid in all_roles:
                affected.add(eid)
        elif etype == "profile":
            affected.update(profile_to_roles.get(eid, set()))
        elif etype == "module":
            for prof in module_to_profiles.get(eid, set()):
                affected.update(profile_to_roles.get(prof, set()))
        elif etype == "os-data":
            hints = OS_TO_ROLE_HINTS.get(eid, ())
            if hints:
                for role in all_roles:
                    name = role.lower()
                    if any(h in name for h in hints):
                        affected.add(role)
        elif etype == "common-data":
            affected.update(all_roles)

    worker_pools, azure_images = [], []
    for role in sorted(affected):
        if "azure" in role.lower():
            azure_images.append(role)
        else:
            worker_pools.append(role)
    return {"worker_pools": worker_pools, "azure_images": azure_images}


def parse_ai_response(text):
    """Returns (parsed_dict, error). On success parsed_dict has description/headline/tags."""
    if not text or not text.strip():
        return None, "empty AI response"

    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.splitlines()
        lines = lines[1:] if lines[0].startswith("```") else lines
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        cleaned = "\n".join(lines).strip()

    try:
        obj = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        return None, f"AI response not valid JSON: {exc}"

    if not isinstance(obj, dict):
        return None, "AI response was not a JSON object"

    description = obj.get("description")
    if not isinstance(description, str) or not description.strip():
        return None, "AI response missing non-empty 'description' string"

    headline = obj.get("headline")
    if headline is not None and not isinstance(headline, str):
        headline = None
    if isinstance(headline, str):
        headline = headline.strip()[:120] or None

    raw_tags = obj.get("tags") or []
    if not isinstance(raw_tags, list):
        raw_tags = []
    tags = []
    for t in raw_tags:
        if isinstance(t, str) and t.strip() and t.strip() not in tags:
            tags.append(t.strip())

    return {"description": description.strip(), "headline": headline, "tags": tags}, None


def build_ai_summary(model, generated_at, ai_outcome, response_text):
    base = {"model": model, "generated_at": generated_at}
    if ai_outcome != "success":
        return {**base, "description": None, "headline": None, "tags": [],
                "error": f"ai-inference step outcome: {ai_outcome}"}

    parsed, err = parse_ai_response(response_text)
    if err:
        return {**base, "description": None, "headline": None, "tags": [], "error": err}

    return {**base, "description": parsed["description"],
            "headline": parsed["headline"], "tags": parsed["tags"], "error": None}


def cmd_map_entities(args):
    paths = Path(args.changed_files).read_text().splitlines()
    entities = map_files_to_entities(paths)
    Path(args.output).write_text(json.dumps(entities, indent=2) + "\n")
    print(f"Mapped {len(paths)} paths to {len(entities)} entities -> {args.output}")


def cmd_assemble(args):
    entities = json.loads(Path(args.entities_file).read_text())
    if not entities:
        print("No entities; refusing to assemble event.", file=sys.stderr)
        sys.exit(1)

    response_text = ""
    if args.ai_response_file and Path(args.ai_response_file).exists():
        response_text = Path(args.ai_response_file).read_text()

    ai_summary = build_ai_summary(
        model=args.ai_model,
        generated_at=args.ai_generated_at,
        ai_outcome=args.ai_outcome,
        response_text=response_text,
    )

    pr_number = int(args.pr_number) if args.pr_number.strip() else None
    pr_url = f"https://github.com/{args.source_repo}/pull/{pr_number}" if pr_number else None

    impact = compute_impact(entities, args.repo_root)

    event = {
        "schema_version": "1",
        "source_repo": args.source_repo,
        "commit_sha": args.commit_sha,
        "commit_url": args.commit_url,
        "pr_number": pr_number,
        "pr_url": pr_url,
        "actor": args.actor,
        "timestamp": args.timestamp,
        "commit_subject": args.commit_subject,
        "ai_summary": ai_summary,
        "entities": entities,
        "impact": impact,
    }

    schema = json.loads(Path(args.schema_file).read_text())
    jsonschema.validate(event, schema)

    Path(args.output).write_text(json.dumps(event, indent=2) + "\n")
    print(f"Wrote validated event -> {args.output}")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_map = sub.add_parser("map-entities")
    p_map.add_argument("--changed-files", required=True)
    p_map.add_argument("--output", required=True)
    p_map.set_defaults(func=cmd_map_entities)

    p_asm = sub.add_parser("assemble")
    p_asm.add_argument("--schema-file", required=True)
    p_asm.add_argument("--source-repo", required=True)
    p_asm.add_argument("--commit-sha", required=True)
    p_asm.add_argument("--commit-url", required=True)
    p_asm.add_argument("--pr-number", default="")
    p_asm.add_argument("--actor", required=True)
    p_asm.add_argument("--timestamp", required=True)
    p_asm.add_argument("--commit-subject", required=True)
    p_asm.add_argument("--entities-file", required=True)
    p_asm.add_argument("--ai-model", required=True)
    p_asm.add_argument("--ai-generated-at", required=True)
    p_asm.add_argument("--ai-outcome", required=True)
    p_asm.add_argument("--ai-response-file", default="")
    p_asm.add_argument("--repo-root", default=".", help="Repo root for impact analysis")
    p_asm.add_argument("--output", required=True)
    p_asm.set_defaults(func=cmd_assemble)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
