#!/usr/bin/python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""Configure the physical GNOME Wayland display before starting a Talos worker.

Uses Mutter 46's org.gnome.Mutter.DisplayConfig interface. The monitor or EDID
adapter must advertise 1600x1200 at 60 Hz; Xorg modelines do not configure KMS.
"""

import os
import sys
import time


def select_display(monitors, logical_monitors):
    """Prefer the primary output, requiring an unscaled, progressive 60 Hz mode."""
    primary = {
        spec[0] for logical in logical_monitors if logical[4] for spec in logical[5]
    }
    candidates = []
    for spec, modes, _properties in monitors:
        for mode in modes:
            mode_id, width, height, rate, _scale, scales, properties = mode
            if (
                (width, height) == (1600, 1200)
                and abs(rate - 60.0) < 0.1
                and 1.0 in scales
                and not properties.get("is-interlaced", False)
            ):
                candidates.append(
                    (spec[0] not in primary, abs(rate - 60.0), spec[0], mode_id)
                )
    if not candidates:
        raise RuntimeError("No connected output supports unscaled 1600x1200 at 60 Hz")
    _, _, connector, mode_id = min(candidates)
    return connector, mode_id


def display_is_ready(monitors, logical_monitors, connector, mode_id):
    if len(logical_monitors) != 1:
        return False
    x, y, scale, transform, primary, specs, _properties = logical_monitors[0]
    if (x, y, scale, transform, primary) != (0, 0, 1.0, 0, True):
        return False
    if len(specs) != 1 or specs[0][0] != connector:
        return False
    return any(
        spec[0] == connector and mode[0] == mode_id and mode[6].get("is-current", False)
        for spec, modes, _properties in monitors
        for mode in modes
    )


def configure_display():
    # GI is provided by Ubuntu's python3-gi package; use the system interpreter.
    from gi.repository import Gio, GLib

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    def call(method, parameters=None):
        return bus.call_sync(
            "org.gnome.Mutter.DisplayConfig",
            "/org/gnome/Mutter/DisplayConfig",
            "org.gnome.Mutter.DisplayConfig",
            method,
            parameters,
            None,
            Gio.DBusCallFlags.NONE,
            5000,
            None,
        ).unpack()

    # Autostart can race compositor initialization or a connector hotplug. Read
    # a fresh serial on every attempt, and verify the resulting active layout.
    deadline = time.monotonic() + 60
    last_error = "Display configuration did not become active"
    while time.monotonic() < deadline:
        try:
            serial, monitors, logical, _properties = call("GetCurrentState")
            connector, mode_id = select_display(monitors, logical)
            if display_is_ready(monitors, logical, connector, mode_id):
                print(
                    f"Wayland display ready: {connector} {mode_id}, scale 1", flush=True
                )
                return
            call(
                "ApplyMonitorsConfig",
                GLib.Variant(
                    "(uua(iiduba(ssa{sv}))a{sv})",
                    (serial, 1, [(0, 0, 1.0, 0, True, [(connector, mode_id, {})])], {}),
                ),
            )
        except (GLib.Error, RuntimeError) as error:
            last_error = str(error)
        time.sleep(2)
    raise RuntimeError(f"Wayland display setup timed out: {last_error}")


def main():
    if os.environ.get("XDG_SESSION_TYPE") != "wayland" or not os.environ.get(
        "WAYLAND_DISPLAY"
    ):
        raise RuntimeError("Worker requires a Wayland session with WAYLAND_DISPLAY set")
    configure_display()
    os.environ["MOZ_ENABLE_WAYLAND"] = "1"
    os.execv(
        "/usr/local/bin/run-start-worker-wrapper.sh", ["run-start-worker-wrapper.sh"]
    )


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"Worker not started: {error}", file=sys.stderr)
        sys.exit(1)
