#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "pyyaml",
# ]
# ///
"""
This script will update all the requirements files.
"""
import os.path
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


here = Path(__file__).parent
COMMON_YAML = here.parent.parent.parent / "data" / "common.yaml"


def run():
    with open(COMMON_YAML) as fh:
        scriptworker_config = yaml.load(fh, Loader=yaml.Loader)["scriptworker_config"]

    with tempfile.TemporaryDirectory() as git_dir, tempfile.TemporaryDirectory() as req_dir:
        print("Cloning scriptworker scripts repository")
        subprocess.run(["git", "init"], cwd=git_dir)
        subprocess.run(["git", "remote", "add", "origin", "https://github.com/mozilla-releng/scriptworker-scripts.git"], cwd=git_dir)
        subprocess.run(["git", "fetch", "-a", "origin"], cwd=git_dir)

        for name, config in scriptworker_config.items():
            print(f"Updating requirements for {name}..")
            scriptworker_revision = config["scriptworker_revision"]
            scriptworker_scripts_revision = config["scriptworker_scripts_revision"]
            subprocess.run(["git", "reset", "--hard", scriptworker_scripts_revision], cwd=git_dir)

            all_reqs = [f"https://raw.githubusercontent.com/mozilla-releng/scriptworker/{scriptworker_revision}/requirements.txt"]
            for package_name in ("iscript", "scriptworker-client"):
                package_req = os.path.join(req_dir, f"{package_name}.txt")
                subprocess.run(
                    [
                        "uv",
                        "export",
                        "--no-editable",
                        "--no-annotate",
                        "--no-dev",
                        "--python",
                        "3.11",
                        "--package",
                        package_name,
                        "-o",
                        package_req,
                    ],
                    cwd=git_dir,
                )
                all_reqs.append(package_req)

            output_file = here / f"requirements.{name}.txt"

            with tempfile.NamedTemporaryFile(delete_on_close=False, suffix=".in") as fp:
                data = "-r " + "\n-r ".join(all_reqs)
                fp.write(data.encode("utf-8"))
                fp.seek(0)
                fp.close()

                subprocess.run(
                    [
                        "uv",
                        "pip",
                        "compile",
                        "-q",
                        "--upgrade",
                        "--universal",
                        "--no-sources",
                        "--python-version=3.11",
                        "--generate-hashes",
                        "-o",
                        output_file,
                        fp.name,
                    ],
                    cwd=git_dir,
                )

    print("Done!")


if __name__ == "__main__":
    sys.exit(run())
