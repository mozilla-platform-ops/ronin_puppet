#!/usr/bin/env python3
"""
Updates common.yaml scriptworker-scripts revisions with latest master/main commit hashes
"""

import asyncio
import aiohttp
from os import path, replace
import re

DIRECTIVES = [
    {
        "common_key": "scriptworker_scripts_revision",
        "repo": "mozilla-releng/scriptworker-scripts",
        "branch": "master",
    },
]


async def getLatestCommit(session, repo, branch):
    async with session.get(
        f"https://api.github.com/repos/{repo}/commits/{branch}"
    ) as response:
        data = await response.json()
        print("-----")
        print(f"{repo} last commit: {data['commit']['message']}")
        print(f"{repo} sha: {data['sha']}")
        print("-----")
        return {repo: data["sha"]}


async def main():
    common_yaml = path.join(path.dirname(__file__), "common.yaml")

    # Get data from GitHub
    async with aiohttp.ClientSession() as session:
        responses = await asyncio.gather(
            *[getLatestCommit(session, d["repo"], d["branch"]) for d in DIRECTIVES],
            return_exceptions=True,
        )
    print(responses)

    # Populate directives
    for r in responses:
        for d in DIRECTIVES:
            if d["repo"] in r:
                d["sha"] = r[d["repo"]]

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
    asyncio.run(main())
