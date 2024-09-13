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

import subprocess
import sys
import tempfile
from pathlib import Path
from textwrap import dedent

import yaml


here = Path(__file__).parent
COMMON_YAML = here.parent.parent.parent / "data" / "common.yaml"


def run():
    with open(COMMON_YAML) as fh:
        scriptworker_config = yaml.load(fh, Loader=yaml.Loader)["scriptworker_config"]

    for name, config in scriptworker_config.items():
        scriptworker_revision = config["scriptworker_revision"]
        scriptworker_scripts_revision = config["scriptworker_scripts_revision"]

        output_file = here / f"requirements.{name}.txt"

        with tempfile.NamedTemporaryFile(delete_on_close=False, suffix=".in") as fp:
            fp.write(
                dedent(
                    f"""
                -r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/{scriptworker_scripts_revision}/scriptworker_client/requirements/base.in
                -r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/{scriptworker_scripts_revision}/iscript/requirements/base.in
                -r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/{scriptworker_scripts_revision}/notarization_poller/requirements/base.in
                -r https://raw.githubusercontent.com/mozilla-releng/scriptworker/{scriptworker_revision}/requirements.txt
                # mozbuild dependencies
                jsmin>=3
                mozfile
                # widevine dependencies
                cryptography
                macholib
            """
                ).encode("utf-8")
            )
            fp.close()

            with open(fp.name, "r") as fh:
                print(fh.read())

            subprocess.run(
                [
                    "uv",
                    "pip",
                    "compile",
                    "--universal",
                    "--generate-hashes",
                    "-o",
                    output_file,
                    fp.name,
                ]
            )


if __name__ == "__main__":
    sys.exit(run())
