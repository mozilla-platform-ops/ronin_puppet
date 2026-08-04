#!/usr/bin/env python3
"""Update the scriptworker-scripts revision in common.yaml."""

import json
from pathlib import Path
import re
from urllib.request import urlopen

COMMON_KEY = "scriptworker_scripts_revision"
REPO = "mozilla-releng/scriptworker-scripts"
BRANCH = "master"


def replace_revision(content, sha):
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError(f"GitHub returned an invalid commit SHA: {sha!r}")

    updated, count = re.subn(
        rf"^(.*{COMMON_KEY}: ).*$",
        rf'\g<1>"{sha}"',
        content,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise RuntimeError(f"Expected one {COMMON_KEY} entry, found {count}")
    return updated


def main():
    with urlopen(
        f"https://api.github.com/repos/{REPO}/commits/{BRANCH}", timeout=30
    ) as response:
        data = json.load(response)

    print(f"{REPO} last commit: {data['commit']['message']}")
    print(f"{REPO} sha: {data['sha']}")

    common_yaml = Path(__file__).with_name("common.yaml")
    content = common_yaml.read_text(encoding="utf-8")
    updated = replace_revision(content, data["sha"])

    tmp_common_yaml = common_yaml.with_name(f"{common_yaml.name}.tmp")
    tmp_common_yaml.write_text(updated, encoding="utf-8")
    tmp_common_yaml.replace(common_yaml)
    print(f"Replaced {COMMON_KEY} with {data['sha']}")


if __name__ == "__main__":
    main()
