#!/usr/bin/env python3

import argparse
import pprint
import re
import subprocess

FILTER_STRING = re.escape("Safari")

# python heredoc
TEST_OUTPUT = """
Software Update Tool

Finding available software
Software Update found the following new or updated software:
* Label: Safari17.4.1VenturaAuto-17.4.1
	Title: Safari, Version: 17.4.1, Size: 168878KiB, Recommended: YES,
* Label: SafariTechPreview99.9.1VenturaAuto-FAKE-AJE-17.4.1
	Title: Safari, Version: 17.4.1, Size: 168878KiB, Recommended: YES,
* Label: macOS Ventura 13.6.6-22G630
	Title: macOS Ventura 13.6.6, Version: 13.6.6, Size: 1134734KiB, Recommended: YES, Action: restart,
* Label: macOS Sonoma 14.4.1-23E224
	Title: macOS Sonoma 14.4.1, Version: 14.4.1, Size: 7111833KiB, Recommended: YES, Action: restart,

"""


def main(args, injected_output=None):
    # Run the softwareupdate command and get the output
    if injected_output:
        output = injected_output
    else:
        output = subprocess.check_output(["softwareupdate", "--list"]).decode("utf-8")
    if args.verbose:
        print(output)

    # Find all labels mentioning Safari (case insensitive)
    all_package_matches = re.findall(
        r"Label: ([\w\.\-\ ]*)", output, flags=re.IGNORECASE
    )
    # matches = re.findall(r"Label: ([\w\.\-\ ])*", output, flags=re.IGNORECASE)

    print("all packages found: ")
    pprint.pprint(all_package_matches)
    print("")

    # insert the filter string into the re string
    re_string = r"Label: (" + FILTER_STRING + r"[\w\.\-\ ]*)"
    # convert re_string to regexp
    re_filter = re.compile(re_string, flags=re.IGNORECASE)
    all_filtered_matches = re_filter.findall(output)

    print("filtered packages found: ")
    pprint.pprint(all_filtered_matches)
    print("")

    # Install updates for each match
    for match in all_filtered_matches:
        label = match.strip()
        if args.noop:
            print(f"NOOP MODE: would have installed {label}")
        else:
            print(f"Installing {label}...")
            subprocess.run(["softwareupdate", "--install", label])


# check if this is being called as a script
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Install updates for a specific software package"
    )
    parser.add_argument("--verbose", help="Enable verbose mode", action="store_true")
    parser.add_argument(
        "--testing",
        help="Enable testing mode, use canned data vs calling softwareupdate",
        action="store_true",
    )
    parser.add_argument(
        "--noop", help="No operation, don't install updates.", action="store_true"
    )
    args = parser.parse_args()

    if args.testing:
        # don't install canned data packages... probably don't exist
        args.noop = True
        main(args, injected_output=TEST_OUTPUT)
    else:
        main(args)
