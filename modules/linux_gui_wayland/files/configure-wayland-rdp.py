#!/usr/bin/python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""Enable RDP sharing of the existing GNOME worker session after autologin."""

import fcntl
import getpass
import json
import os
import secrets
import socket
import subprocess
import sys
from pathlib import Path


class SetupError(Exception):
    """A diagnostic message that contains no credentials."""


def run(*arguments, **kwargs):
    return subprocess.run(
        arguments,
        check=True,
        timeout=30,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        **kwargs,
    )


def load_credentials(directory):
    # Keyring activation and desktop autostart may initialize concurrently.
    # Keep this lock separate from the full RDP setup lock to avoid a D-Bus
    # activation deadlock while waiting for the keyring service to start.
    with (directory / ".credentials.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        credentials_file = directory / "credentials.json"
        if not credentials_file.exists():
            with credentials_file.open("x") as stream:
                json.dump(
                    {
                        "username": getpass.getuser(),
                        "password": secrets.token_urlsafe(24),
                    },
                    stream,
                )
        credentials = json.loads(credentials_file.read_text())
        credentials_file.chmod(0o600)
        return credentials


def start_keyring():
    directory = Path.home() / ".config/ronin-wayland-rdp"
    arguments = [
        "gnome-keyring-daemon",
        "--foreground",
        "--components=pkcs11,secrets",
        "--control-directory=" + str(Path(os.environ["XDG_RUNTIME_DIR"]) / "keyring"),
    ]
    if directory.is_dir():
        os.umask(0o077)
        credentials = load_credentials(directory)
        read_fd, write_fd = os.pipe()
        os.write(write_fd, credentials["password"].encode())
        os.close(write_fd)
        os.dup2(read_fd, 0)
        os.close(read_fd)
        arguments.append("--unlock")
    os.execv("/usr/bin/gnome-keyring-daemon", arguments)


def configure(directory):
    import gi

    gi.require_version("Secret", "1")
    from gi.repository import Gio, GLib, Secret

    # GNOME's idle screen shield inhibits remote session creation even when
    # lock-enabled is false. Keep the unattended worker desktop awake.
    session_settings = Gio.Settings.new("org.gnome.desktop.session")
    session_settings.set_uint("idle-delay", 0)
    power_settings = Gio.Settings.new("org.gnome.settings-daemon.plugins.power")
    power_settings.set_boolean("idle-dim", False)
    Gio.Settings.sync()

    credentials = load_credentials(directory)

    certificate = directory / "server.crt"
    key = directory / "server.key"
    if not certificate.exists() or not key.exists():
        run(
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-days",
            "3650",
            "-subj",
            f"/CN={socket.getfqdn()}",
            "-keyout",
            str(key),
            "-out",
            str(certificate),
        )

    service = Secret.Service.get_sync(
        Secret.ServiceFlags.OPEN_SESSION | Secret.ServiceFlags.LOAD_COLLECTIONS, None
    )
    collection = Secret.Collection.for_alias_sync(
        service, Secret.COLLECTION_DEFAULT, Secret.CollectionFlags.NONE, None
    )
    if collection is None:
        collection = Secret.Collection.for_alias_sync(
            service, "login", Secret.CollectionFlags.NONE, None
        )
        if collection is not None and not collection.get_locked():
            service.set_alias_sync(Secret.COLLECTION_DEFAULT, collection, None)
    if collection is None or collection.get_locked():
        raise SetupError("Autologin keyring is unavailable or locked")

    schema = Secret.Schema.new(
        "org.gnome.RemoteDesktop.RdpCredentials",
        Secret.SchemaFlags.NONE,
        {"credentials": Secret.SchemaAttributeType.STRING},
    )
    value = GLib.Variant(
        "a{sv}",
        {
            "username": GLib.Variant("s", credentials["username"]),
            "password": GLib.Variant("s", credentials["password"]),
        },
    ).print_(True)
    if not Secret.password_store_sync(
        schema,
        {},
        Secret.COLLECTION_DEFAULT,
        "GNOME Remote Desktop RDP credentials",
        value,
        None,
    ):
        raise SetupError("Could not store RDP credentials in the session keyring")

    for command, value in (("set-tls-cert", certificate), ("set-tls-key", key)):
        run("grdctl", "rdp", command, str(value))
    run("grdctl", "rdp", "disable-view-only")
    run("grdctl", "rdp", "disable-port-negotiation")
    run("grdctl", "rdp", "set-port", "3389")
    settings = Gio.Settings.new("org.gnome.desktop.remote-desktop.rdp")
    settings.set_string("screen-share-mode", "mirror-primary")
    Gio.Settings.sync()
    run("grdctl", "rdp", "enable")
    run("systemctl", "--user", "start", "gnome-remote-desktop.service")
    print("GNOME RDP desktop sharing configured on port 3389", flush=True)


def main():
    directory = Path.home() / ".config/ronin-wayland-rdp"
    # This is a system-wide autostart entry; only the configured worker user
    # has this directory. Other desktop users should do nothing.
    if not directory.is_dir():
        return
    if os.environ.get("XDG_SESSION_TYPE") != "wayland":
        raise SetupError("RDP setup requires the worker Wayland session")
    os.umask(0o077)
    with (directory / ".setup.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        configure(directory)


if __name__ == "__main__":
    try:
        if "--keyring-daemon" in sys.argv:
            start_keyring()
        else:
            main()
    except Exception as error:  # noqa: BLE001 - Never expose credential-bearing exception data.
        # Do not print credential contents or subprocess output.
        detail = str(error) if isinstance(error, SetupError) else type(error).__name__
        print(f"Worker RDP setup failed: {detail}", file=sys.stderr)
        sys.exit(1)
