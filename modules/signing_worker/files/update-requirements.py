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
from pathlib import Path
from tempfile import TemporaryDirectory, NamedTemporaryFile

import yaml


here = Path(__file__).parent
COMMON_YAML = here.parent.parent.parent / "data" / "common.yaml"


def run():
    with open(COMMON_YAML) as fh:
        scriptworker_config = yaml.load(fh, Loader=yaml.Loader)["scriptworker_config"]

    with TemporaryDirectory() as ss_git_dir, TemporaryDirectory() as req_dir, TemporaryDirectory() as scriptworker_git_dir:
        print("Cloning scriptworker scripts repository")
        subprocess.run(["git", "init"], cwd=ss_git_dir)
        subprocess.run(["git", "remote", "add", "origin", "https://github.com/mozilla-releng/scriptworker-scripts.git"], cwd=ss_git_dir)
        subprocess.run(["git", "fetch", "-a", "origin"], cwd=ss_git_dir)

        print("Cloning scriptworker repository")
        subprocess.run(["git", "init"], cwd=scriptworker_git_dir)
        subprocess.run(["git", "remote", "add", "origin", "https://github.com/mozilla-releng/scriptworker.git"], cwd=scriptworker_git_dir)
        subprocess.run(["git", "fetch", "-a", "origin"], cwd=scriptworker_git_dir)

        for name, config in scriptworker_config.items():
            print(f"Updating requirements for {name}..")
            scriptworker_revision = config["scriptworker_revision"]
            scriptworker_scripts_revision = config["scriptworker_scripts_revision"]

            # Checkout the specific revisions
            subprocess.check_call(["git", "reset", "--hard", scriptworker_scripts_revision], cwd=ss_git_dir)
            subprocess.check_call(["git", "reset", "--hard", scriptworker_revision], cwd=scriptworker_git_dir)

            scriptworker_req = os.path.join(req_dir, "scriptworker.txt")
            subprocess.check_call(
                [
                    "uv",
                    "export",
                    "--no-editable",
                    "--no-annotate",
                    "--no-emit-project",
                    "--no-dev",
                    "--python=3.11",
                    "--quiet",
                    "-o",
                    scriptworker_req,
                ],
                cwd=scriptworker_git_dir,
            )

            all_reqs = [scriptworker_req]

            for package_name in ("iscript", "scriptworker-client"):
                package_req = os.path.join(req_dir, f"{package_name}.txt")
                subprocess.check_call(
                    [
                        "uv",
                        "export",
                        "--no-editable",
                        "--no-annotate",
                        "--no-emit-project",
                        "--no-emit-workspace",
                        "--no-emit-package=mozbuild",
                        "--no-dev",
                        "--python=3.11",
                        "--quiet",
                        "--package",
                        package_name,
                        "-o",
                        package_req,
                    ],
                    cwd=ss_git_dir,
                )
                all_reqs.append(package_req)

            output_file = here / f"requirements.{name}.txt"

            with NamedTemporaryFile(delete_on_close=False, suffix=".in") as fp:
                data = "-r " + "\n-r ".join(all_reqs)
                fp.write(data.encode("utf-8"))
                fp.seek(0)
                fp.close()

                subprocess.check_call(
                    [
                        "uv",
                        "pip",
                        "compile",
                        "-q",
                        f"--overrides={req_dir}/iscript.txt",
                        f"--overrides={req_dir}/scriptworker-client.txt",
                        "--upgrade",
                        "--no-sources",
                        "--python-version=3.11",
                        "--python-platform=aarch64-apple-darwin",
                        "--generate-hashes",
                        "--no-header",
                        "--quiet",
                        "-o",
                        output_file,
                        fp.name,
                    ],
                    cwd=ss_git_dir,
                )

    print("Done!")


if __name__ == "__main__":
    sys.exit(run())
