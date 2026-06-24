#!/usr/bin/env python3
"""
Updates common.yaml scriptworker-scripts revisions with latest master/main commit hashes
"""

import json
from os import path, replace
import re
from urllib.request import urlopen

DIRECTIVES = [
    {
        "common_key": "scriptworker_scripts_revision",
        "repo": "mozilla-releng/scriptworker-scripts",
        "branch": "master",
    },
]


def get_latest_commit(repo, branch):
    with urlopen(f"https://api.github.com/repos/{repo}/commits/{branch}") as response:
        data = json.load(response)

    print("-----")
    print(f"{repo} last commit: {data['commit']['message']}")
    print(f"{repo} sha: {data['sha']}")
    print("-----")
    return data["sha"]


async def main():
    common_yaml = path.join(path.dirname(__file__), "common.yaml")

    for directive in DIRECTIVES:
        directive["sha"] = get_latest_commit(directive["repo"], directive["branch"])

    # Read the file
    with open(common_yaml, "r") as f:
        content = f.read()

    # Apply replacements
    for directive in DIRECTIVES:
        pattern = f"(.*{directive['common_key']}: ).*"
        replacement = rf'\1"{directive["sha"]}"'
        content = re.sub(pattern, replacement, content)
        print(f"Replaced {directive['common_key']} with {directive['sha']}")

    # Write the file atomically (to tmp first, then override whole file)
    tmp_common_yaml = f"{common_yaml}.tmp"
    with open(tmp_common_yaml, "w") as f:
        f.write(content)
    replace(tmp_common_yaml, common_yaml)


if __name__ == "__main__":
    main()
