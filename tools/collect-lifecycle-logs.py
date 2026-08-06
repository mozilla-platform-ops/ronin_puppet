#!/usr/bin/env python3
"""Collect Linux host-lifecycle logs over SSH into timestamped snapshots."""

import argparse
import datetime
import pathlib
import re
import subprocess
import sys
import tarfile


REMOTE_LOG_DIRECTORY = "/var/log/host-lifecycle"
HOST_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
EVENT_FILE_PATTERN = re.compile(r"^events\.jsonl(?:\.\d+)?(?:\.gz)?$")


class CollectionError(RuntimeError):
    """A requested host could not be collected."""


def snapshot_name(now=None):
    timestamp = now or datetime.datetime.now(datetime.timezone.utc)
    return timestamp.strftime("%Y%m%dT%H%M%SZ")


def create_snapshot(output_directory, now=None):
    """Create a fresh timestamped destination, refusing to overwrite one."""
    destination = pathlib.Path(output_directory) / snapshot_name(now)
    destination.mkdir(parents=True, exist_ok=False)
    return destination


def validate_host(host):
    if not HOST_PATTERN.fullmatch(host):
        raise ValueError("invalid host name: {!r}".format(host))
    return host


def remote_archive_command():
    """Return the fixed remote command that streams only lifecycle event files."""
    return (
        "set -e; cd {directory}; "
        "find . -maxdepth 1 -type f -name 'events.jsonl*' -print0 | "
        "tar --null --files-from=- --create --gzip --file=-"
    ).format(directory=REMOTE_LOG_DIRECTORY)


def safe_extract(archive_path, destination):
    """Extract only known lifecycle event files, rejecting unsafe tar members."""
    with tarfile.open(archive_path, "r:gz") as archive:
        found_active_log = False
        for member in archive.getmembers():
            relative_path = pathlib.PurePosixPath(member.name).as_posix()
            if relative_path.startswith("./"):
                relative_path = relative_path[2:]
            if not member.isfile() or not EVENT_FILE_PATTERN.fullmatch(relative_path):
                raise CollectionError("unexpected file in lifecycle archive: {}".format(member.name))
            if relative_path == "events.jsonl":
                found_active_log = True
            target = pathlib.Path(destination) / relative_path
            with archive.extractfile(member) as source, target.open("wb") as extracted:
                if source is None:
                    raise CollectionError("could not read lifecycle archive member: {}".format(member.name))
                chunk = source.read(1024 * 1024)
                while chunk:
                    extracted.write(chunk)
                    chunk = source.read(1024 * 1024)
        if not found_active_log:
            raise CollectionError("lifecycle archive did not contain events.jsonl")


def collect_host(host, snapshot_directory):
    """Collect one host's event files into its host-named snapshot directory."""
    host = validate_host(host)
    host_directory = pathlib.Path(snapshot_directory) / host
    host_directory.mkdir(exist_ok=False)
    archive_path = host_directory / ".events.tar.gz"
    command = ["ssh", host, remote_archive_command()]
    try:
        with archive_path.open("wb") as archive_file:
            result = subprocess.run(
                command, stdout=archive_file, stderr=subprocess.PIPE, universal_newlines=True
            )
        if result.returncode:
            raise CollectionError("{}: {}".format(host, result.stderr.strip() or "ssh collection failed"))
        safe_extract(archive_path, host_directory)
    except (OSError, tarfile.TarError) as error:
        raise CollectionError("{}: {}".format(host, error)) from error
    finally:
        try:
            archive_path.unlink()
        except FileNotFoundError:
            pass
    return host_directory


def parse_args(arguments):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-directory",
        default="lifecycle-log-snapshots",
        help="parent directory for timestamped snapshots (default: %(default)s)",
    )
    parser.add_argument("hosts", nargs="+", help="SSH host names to collect")
    return parser.parse_args(arguments)


def main(arguments=None):
    args = parse_args(arguments)
    snapshot_directory = create_snapshot(args.output_directory)
    failures = []
    for host in args.hosts:
        try:
            destination = collect_host(host, snapshot_directory)
            print("collected {} -> {}".format(host, destination))
        except (CollectionError, ValueError) as error:
            print("collection failed: {}".format(error), file=sys.stderr)
            failures.append(host)
    if failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
