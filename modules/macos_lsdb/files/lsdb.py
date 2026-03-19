#!/usr/bin/env python3
import subprocess
import re
import sys
import argparse
import logging
from pathlib import Path

LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
logger = logging.getLogger("lsdb-prune")

def check_lsregister():
    if not Path(LSREGISTER).is_file():
        logger.error("lsregister not found at expected path: %s", LSREGISTER)
        sys.exit(1)

def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Print, check, or delete stale paths from the "
            "LaunchServices database."
        )
    )
    parser.add_argument(
        "-p", "--print-paths", action="store_true",
        help="Print all paths in the LaunchServices database (default)")
    parser.add_argument(
        "-s", "--print-stale", action="store_true",
        help="Print stale paths (paths no longer on the filesystem)")
    parser.add_argument(
        "-d", "--delete-stale", action="store_true",
        help="Delete stale paths from the database")
    parser.add_argument(
        "-i", "--stdin", action="store_true",
        help="Read lsregister -dump output from stdin instead of running it.")
    return parser.parse_args()

def configure_logging():
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
    logger.setLevel(logging.INFO)

def main():
    args = parse_args()
    configure_logging()
    check_lsregister()

    if args.stdin:
        dump_lines = sys.stdin.read().splitlines()
    else:
        result = subprocess.run([LSREGISTER, "-dump"], capture_output=True, text=True)
        dump_lines = result.stdout.splitlines()

    # Match lines in the lsregister -dump output and pull out the path.
    # The lines to match are in the following format.
    #   ^path:<whitespace><path> (0x+)$
    # Such as
    #   path:    /Applications/Foo.app (0x123ABC)
    path_re = re.compile(r"path:\s+(.+?) \(0x.+\)$", re.IGNORECASE)
    paths = []
    for line in dump_lines:
        match = path_re.search(line)
        if match:
            paths.append(match.group(1))

    # Default to print-paths if no other option is specified
    if not (args.print_paths or args.print_stale or args.delete_stale):
        args.print_paths = True

    if args.print_paths:
        logger.info(f"printing all paths in database")
    elif args.print_stale:
        logger.info(f"printing stale paths in database")
    elif args.delete_stale:
        logger.info(f"deleting stale paths from database")

    total_count = 0
    stale_count = 0
    delete_count = 0

    for path_str in paths:
        path_obj = Path(path_str)
        total_count += 1

        if not path_obj.exists():
            stale_count += 1

        if args.print_paths:
            print(path_str)
        elif args.print_stale:
            if not path_obj.exists():
                print(path_str)
        elif args.delete_stale:
            if not path_obj.exists():
                logger.info(f"deleting {path_str}")
                delete_count += 1
                result = subprocess.run(
                    [LSREGISTER, "-u", "-v", str(path_str)],
                    check=False,
                    capture_output=True,
                    text=True
                )
                #if result.stdout:
                #    logger.info(result.stdout.strip())
                if result.stderr:
                    logger.error(result.stderr.strip())

    logger.info(f"{total_count} paths in database")
    logger.info(f"{stale_count} stale paths found")
    logger.info(f"{delete_count} paths attempted to be deleted from database")

if __name__ == "__main__":
    main()
