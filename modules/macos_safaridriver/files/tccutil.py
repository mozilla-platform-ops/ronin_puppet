#!/usr/bin/env python

# ****************************************************************************
# tccutil.py, Utility to modify the macOS Accessibility Database (TCC.db)
#
# Copyright (C) 2020, @jacobsalmela
#
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, either Version 2 or any later
# version.  This program is distributed in the hope that it will be useful,
# but WITTHOUT ANY WARRANTY.  See the included LICENSE file for details.
# *****************************************************************************

import argparse
import hashlib
import os
import sqlite3
import sys
from platform import mac_ver

from packaging.version import Version as version


class TCCUtil:

    default_service = "kTCCServiceAccessibility"
    default_database = "/Library/Application Support/com.apple.TCC/TCC.db"

    def __init__(self):
        self.database = TCCUtil.default_database
        self.service = TCCUtil.default_service
        self.verbose = False
        self.client_type = None

        # Set "sudo" to True if called with Admin-Privileges.
        self.sudo = True if os.getuid() == 0 else False
        # Current OS X version
        self.osx_version = version(
            mac_ver()[0]
        )  # mac_ver() returns 10.16 for Big Sur instead 11.+

        # db connection handle
        self.conn = None
        # db cursor
        self.c = None

        # Utility Name
        self.util_name = os.path.basename(sys.argv[0])
        # Utility Version
        self.util_version = "1.2.13"

    def display_version(self):
        """Print the version of this utility."""
        print("%s %s" % (self.util_name, self.util_version))
        sys.exit(0)

    def sudo_required(self):
        """Check if user has root priveleges to access the database."""
        if not self.sudo:
            print("Error:")
            print(
                "  When accessing the Accessibility Database, %s needs to be run with admin-privileges.\n"
                % self.util_name
            )
            self.display_help(1)

    def digest_check(self, digest_to_check):
        """Validates that a digest for the table is one that can be used with tccutil."""
        # Do a sanity check that TCC access table has expected structure
        access_table_digest = ""
        for row in digest_to_check.fetchall():
            access_table_digest = hashlib.sha1(row[0].encode("utf-8")).hexdigest()[0:10]
            break

        return access_table_digest

    def open_database(self, digest=False):
        """Open the database for editing values."""
        self.sudo_required()
        # print("using '%s' as database" % self.database)

        # Check if Database is already open, else open it.
        try:
            self.conn.execute("")
        except:
            self.verbose_output("Opening Database...")
        try:
            if not os.path.isfile(self.database):
                print("TCC Database has not been found.")
                sys.exit(1)
            self.conn = sqlite3.connect(self.database)
            self.c = self.conn.cursor()

            # Do a sanity check that TCC access table has expected structure
            access_table_digest = self.digest_check(
                self.c.execute(
                    "SELECT sql FROM sqlite_master WHERE name='access' and type='table'"
                )
            )

            if digest:
                print(access_table_digest)
                sys.exit(0)

            # check if table in DB has expected structure:
            if not (
                access_table_digest == "8e93d38f7c"
                or  # prior to El Capitan
                # El Capitan , Sierra, High Sierra
                (
                    self.osx_version >= version("10.11")
                    and access_table_digest in ["9b2ea61b30", "1072dc0e4b"]
                )
                or
                # Mojave and Catalina
                (
                    self.osx_version >= version("10.14")
                    and access_table_digest in ["ecc443615f", "80a4bb6912"]
                )
                or
                # Big Sur and later
                (
                    self.osx_version >= version("10.16")
                    and access_table_digest in ["3d1c2a0e97", "cef70648de"]
                )
            ):
                print("TCC Database structure is unknown (%s)" % access_table_digest)
                sys.exit(1)

            self.verbose_output("Database opened.\n")
        except TypeError as exc:
            print(
                "Error opening Database.  You probably need to disable SIP for this to work."
            )
            print(exc)
            sys.exit(1)

    def display_help(self, error_code=None):
        """Display help an usage."""
        parser.print_help()
        if error_code is not None:
            sys.exit(error_code)
        print("%s %s" % (self.util_name, self.util_version))
        sys.exit(0)

    def close_database(self):
        """Close the database."""
        try:
            self.conn.execute("")
            try:
                self.verbose_output("Closing Database...")
                self.conn.close()
                try:
                    self.conn.execute("")
                except:
                    self.verbose_output("Database closed.")
            except:
                print("Error closing Database.")
            sys.exit(1)
        except:
            pass

    def commit_changes(self):
        """Apply the changes and close the sqlite connection."""
        self.verbose_output("Committing Changes...\n")
        self.conn.commit()

    def verbose_output(self, *args):
        """Show verbose output."""
        if self.verbose:
            try:
                for a in args:
                    print(a)
            except:
                pass

    def list_clients(self):
        """List items in the database."""
        self.open_database()
        self.c.execute("SELECT client from access WHERE service is '%s'" % self.service)
        self.verbose_output("Fetching Entries from Database...\n")
        for row in self.c.fetchall():
            # print each entry in the Accessibility pane.
            print(row[0])
        self.verbose_output("")

    def list_all_clients(self):
        """List items in the database."""
        self.open_database()

        # TODO: should this just run sqlite DB .dump and show that output?

        # TODO: have a nice columnar format
        #   see https://stackoverflow.com/questions/48138015/printing-table-in-format-without-using-a-library-sqlite-3-python

        self.c.execute("SELECT * from access")

        header = [description[0] for description in self.c.description]
        rows = self.c.fetchall()
        print(" | ".join(header))

        self.verbose_output("Fetching Entries from Database...\n")
        for row in rows:
            print(row)
        self.verbose_output("")

    def cli_util_or_bundle_id(self, client):
        """Check if the item is a path or a bundle ID."""
        # If the app starts with a slash, it is a command line utility.
        # Setting the client_type to 1 will make the item visible in the
        # GUI so you can manually click the checkbox.
        if client[0] == "/":
            self.client_type = 1
            self.verbose_output('Detected "%s" as Command Line Utility.' % client)
        # Otherwise, the app will be a bundle ID, which starts
        # with a com., net., or org., etc.
        else:
            self.client_type = 0
            self.verbose_output('Detected "%s" as Bundle ID.' % client)

    def insert_client(self, client):
        """Insert a client into the database."""
        self.open_database()
        # Check if it is a command line utility or a bundle ID
        # as the default value to enable it is different.
        self.cli_util_or_bundle_id(client)
        self.verbose_output('Inserting "%s" into Database...' % client)
        # Big Sur and later
        if self.osx_version >= version("10.16"):
            try:
                self.c.execute(
                    "INSERT or REPLACE INTO access VALUES('%s','%s',%s,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,0)"
                    % (self.service, client, self.client_type)
                )
            except sqlite3.OperationalError:
                print(
                    "Attempting to write a readonly database.  You probably need to disable SIP."
                )
        # Mojave through Big Sur
        elif self.osx_version >= version("10.14"):
            self.c.execute(
                "INSERT or REPLACE INTO access VALUES('%s','%s',%s,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,0)"
                % (self.service, client, self.client_type)
            )
        # El Capitan through Mojave
        elif self.osx_version >= version("10.11"):
            self.c.execute(
                "INSERT or REPLACE INTO access VALUES('%s','%s',%s,1,1,NULL,NULL)"
                % (self.service, client, self.client_type)
            )
        # Yosemite or lower
        else:
            self.c.execute(
                "INSERT or REPLACE INTO access VALUES('%s','%s',%s,1,1,NULL)"
                % (self.service, client, self.client_type)
            )
        self.commit_changes()

    def delete_client(self, client):
        """Remove a client from the database."""
        self.open_database()
        self.verbose_output('Removing "%s" from Database...' % client)
        try:
            self.c.execute(
                "DELETE from access where client IS '%s' AND service IS '%s'"
                % (client, self.service)
            )
        except sqlite3.OperationalError:
            print(
                "Attempting to write a readonly database.  You probably need to disable SIP."
            )
        self.commit_changes()

    def enable(self, client):
        """Add a client from the database."""
        self.open_database()
        self.verbose_output("Enabling %s..." % (client,))
        # Setting typically appears in System Preferences
        # right away (without closing the window).
        # Set to 1 to enable the client.
        enable_mode_name = (
            "auth_value" if self.osx_version >= version("10.16") else "allowed"
        )
        try:
            self.c.execute(
                "UPDATE access SET %s='1' WHERE client='%s' AND service IS '%s'"
                % (enable_mode_name, client, self.service)
            )
        except sqlite3.OperationalError:
            print(
                "Attempting to write a readonly database.  You probably need to disable SIP."
            )
        self.commit_changes()

    def disable(self, client):
        """Disable a client in the database."""
        self.open_database()
        self.verbose_output("Disabling %s..." % (client,))
        # Setting typically appears in System Preferences
        # right away (without closing the window).
        # Set to 0 to disable the client.
        enable_mode_name = (
            "auth_value" if self.osx_version >= version("10.16") else "allowed"
        )
        try:
            self.c.execute(
                "UPDATE access SET %s='0' WHERE client='%s' AND service IS '%s'"
                % (enable_mode_name, client, self.service)
            )
        except sqlite3.OperationalError:
            print(
                "Attempting to write a readonly database.  You probably need to disable SIP."
            )
        self.commit_changes()

    def main(self):
        args = parser.parse_args()

        # If no arguments are specified, show help menu and exit.
        if not sys.argv[1:]:
            print("Error:")
            print("  No arguments.\n")
            self.display_help(2)

        if args.database:
            self.database = args.database

        if args.version:
            self.display_version()
            return

        if args.action:
            if args.action == "reset":
                exit_status = os.system("tccutil {}".format(" ".join(sys.argv[1:])))
                sys.exit(exit_status / 256)
            else:
                print("Error\n  Unrecognized command {}".format(args.action))

        self.service = args.service

        if args.verbose:
            self.verbose = True

        if args.digest:
            self.open_database(digest=True)

        if args.list:
            self.list_clients()
            return

        if args.list_all:
            self.list_all_clients()
            return

        for item_to_remove in args.remove:
            self.delete_client(item_to_remove)

        for item in args.insert:
            self.insert_client(item)

        for item in args.enable:
            self.enable(item)

        for item in args.disable:
            self.disable(item)

        self.close_database()
        sys.exit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Modify Accesibility Preferences")
    parser.add_argument(
        "action",
        metavar="ACTION",
        type=str,
        nargs="?",
        help="This option is only used to perform a reset.",
    )
    parser.add_argument(
        "--service",
        "-s",
        default=TCCUtil.default_service,
        help="Set TCC service (defaults to %s)" % TCCUtil.default_service,
    )
    parser.add_argument(
        "--list",
        "-l",
        action="store_true",
        help="List all entries in the accessibility database.",
    )
    parser.add_argument(
        "--database",
        "-D",
        default=TCCUtil.default_database,
        help="Database to use (defaults to %s)." % TCCUtil.default_database,
    )
    parser.add_argument(
        "--list-all",
        "-A",
        action="store_true",
        help="List all entries in the accessibility database for all services.",
    )
    parser.add_argument(
        "--digest",
        action="store_true",
        help="Print the digest hash of the accessibility database.",
    )
    parser.add_argument(
        "--insert",
        "-i",
        action="append",
        default=[],
        help="Adds the given bundle ID or path to the accessibility database.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Outputs additional info for some commands.",
    )
    parser.add_argument(
        "-r",
        "--remove",
        action="append",
        default=[],
        help="Removes a given Bundle ID or Path from the Accessibility Database.",
    )
    parser.add_argument(
        "-e",
        "--enable",
        action="append",
        default=[],
        help="Enables Accessibility Access for the given Bundle ID or Path.",
    )
    parser.add_argument(
        "-d",
        "--disable",
        action="append",
        default=[],
        help="Disables Accessibility Access for the given Bundle ID or Path.",
    )
    parser.add_argument(
        "--version",
        action="store_true",
        help="Show the version of this script",
    )

    tccu = TCCUtil()
    tccu.main()
