#!/usr/bin/env python3
"""
Updates common.yaml scriptworker{,-scripts} revisions with latest master/main commit hashes
"""

import asyncio
import aiohttp
from os import path
import subprocess

DIRECTIVES = [
    {
        "common_key": "scriptworker_revision",
        "repo": "mozilla-releng/scriptworker",
        "branch": "main",
    },
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

    for directive in DIRECTIVES:
        cmd = [
            "sed",
            "-i",  # in-place
            "",
            "-E",  # extended
            f"s/(.*{directive['common_key']}\: ).*/\\1\"{directive['sha']}\"/g",
            common_yaml,
        ]
        print(f"Running command: {cmd}")
        subprocess.run(cmd)

    print("Ready to run ./modules/signing_worker/files/update-requirements.sh")


if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(main())
