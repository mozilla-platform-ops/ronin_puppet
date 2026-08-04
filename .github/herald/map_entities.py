#!/usr/bin/env python3
"""Map ronin_puppet changed file paths to Herald entities.

This is the deterministic half of the ronin reporter: given the list of files
touched by a merge commit, produce the ``entities`` array for a Herald change
event (see ``schema/event.schema.json`` in relops-herald). The AI narrative is
added by a separate step in the reporter workflow.

Rules (POC — refine as ronin_puppet's layout is confirmed):

  role    modules/roles_profiles/manifests/roles/<id>.pp
  profile modules/roles_profiles/manifests/profiles/<id>.pp
  module  modules/<name>/...              (id = <name>; roles_profiles excluded)
  role-hiera   data/roles/<id>.yaml
  os-data      data/os/<id>.yaml
  common-data  data/common.yaml           (id = "common")

Staging/alpha entities are excluded by filename pattern (``*_staging.*``,
``*alpha*``), matching the POC scope in the README.

Usage:
    python map_entities.py <file1> <file2> ...        # prints entities JSON
    printf 'a\\nb\\n' | python map_entities.py -       # read paths from stdin
"""

from __future__ import annotations

import fnmatch
import json
import re
import sys
from pathlib import PurePosixPath

# Excluded when the *filename* matches any of these globs.
EXCLUDE_GLOBS = ("*_staging.*", "*alpha*")

# (regex, type, id-from-match) — first match wins.
_ROLE = re.compile(r"^modules/roles_profiles/manifests/roles/(?P<id>[^/]+)\.pp$")
_PROFILE = re.compile(r"^modules/roles_profiles/manifests/profiles/(?P<id>[^/]+)\.pp$")
_ROLE_HIERA = re.compile(r"^data/roles/(?P<id>[^/]+)\.ya?ml$")
_OS_DATA = re.compile(r"^data/os/(?P<id>[^/]+)\.ya?ml$")
_COMMON = re.compile(r"^data/common\.ya?ml$")
_MODULE = re.compile(r"^modules/(?P<id>[^/]+)/")


def is_excluded(path: str) -> bool:
    """True if the file's basename matches a staging/alpha exclusion glob."""
    name = PurePosixPath(path).name
    return any(fnmatch.fnmatch(name, pat) for pat in EXCLUDE_GLOBS)


def classify(path: str) -> tuple[str, str] | None:
    """Return ``(type, id)`` for a path, or None if it maps to no entity."""
    if (m := _ROLE.match(path)):
        return "role", m["id"]
    if (m := _PROFILE.match(path)):
        return "profile", m["id"]
    if (m := _ROLE_HIERA.match(path)):
        return "role-hiera", m["id"]
    if (m := _OS_DATA.match(path)):
        return "os-data", m["id"]
    if _COMMON.match(path):
        return "common-data", "common"
    if (m := _MODULE.match(path)):
        # roles_profiles is decomposed into role/profile above, not a module.
        if m["id"] != "roles_profiles":
            return "module", m["id"]
    return None


def map_files(paths: list[str]) -> list[dict]:
    """Aggregate paths into a deduplicated, sorted list of entity dicts.

    Each entity gets the sorted list of files that mapped to it. Excluded and
    unmapped paths are dropped.
    """
    grouped: dict[tuple[str, str], list[str]] = {}
    for path in paths:
        if is_excluded(path):
            continue
        key = classify(path)
        if key is None:
            continue
        grouped.setdefault(key, []).append(path)

    return [
        {"type": t, "id": i, "files": sorted(files)}
        for (t, i), files in sorted(grouped.items())
    ]


def _self_check() -> None:
    got = map_files(
        [
            "modules/roles_profiles/manifests/roles/gecko_t_linux_2404_talos.pp",
            "modules/roles_profiles/manifests/profiles/gecko_t_linux_2404_talos_generic_worker.pp",
            "modules/generic_worker/manifests/init.pp",
            "modules/generic_worker/templates/config.erb",
            "data/roles/gecko_t_linux_2404_talos.yaml",
            "data/common.yaml",
            "modules/roles_profiles/manifests/roles/gecko_t_linux_2404_talos_staging.pp",  # excluded (staging)
            "modules/roles_profiles/manifests/roles/gecko_t_linux_alpha.pp",  # excluded (alpha)
            "README.md",  # unmapped
        ]
    )
    types = {(e["type"], e["id"]) for e in got}
    assert ("role", "gecko_t_linux_2404_talos") in types, types
    assert ("profile", "gecko_t_linux_2404_talos_generic_worker") in types, types
    assert ("module", "generic_worker") in types, types
    assert ("role-hiera", "gecko_t_linux_2404_talos") in types, types
    assert ("common-data", "common") in types, types
    # generic_worker aggregates both of its touched files.
    gw = next(e for e in got if e["id"] == "generic_worker")
    assert len(gw["files"]) == 2, gw
    # staging + alpha role files (filename patterns) and README are excluded.
    assert not any("staging" in f for e in got for f in e["files"]), got
    assert not any("alpha" in f for e in got for f in e["files"]), got
    print("map_entities self-check OK")


def main(argv: list[str]) -> int:
    if argv == ["--self-check"]:
        _self_check()
        return 0
    if argv == ["-"]:
        paths = [line.strip() for line in sys.stdin if line.strip()]
    else:
        paths = argv
    json.dump(map_files(paths), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
