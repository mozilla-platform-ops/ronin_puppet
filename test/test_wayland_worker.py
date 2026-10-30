"""Exercise physical display selection and worker admission without a desktop."""

import importlib.util
import os
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "modules/linux_gui_wayland/files/start-wayland-worker.py"
)
SPEC = importlib.util.spec_from_file_location("wayland_worker", SCRIPT)
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)


def monitor(connector="DP-1", width=1600, height=1200, rate=60.0, current=True):
    return (
        (connector, "vendor", "product", "serial"),
        [("mode", width, height, rate, 1.0, [1.0], {"is-current": current})],
        {},
    )


def logical(connector="DP-1", scale=1.0):
    return (0, 0, scale, 0, True, [(connector, "vendor", "product", "serial")], {})


class DisplaySelectionTests(unittest.TestCase):
    def test_selects_supported_mode_on_primary_monitor(self):
        monitors = [monitor("DP-1"), monitor("DP-2")]
        self.assertEqual(
            worker.select_display(monitors, [logical("DP-2")]), ("DP-2", "mode")
        )

    def test_accepts_fractional_refresh_near_sixty(self):
        self.assertEqual(
            worker.select_display([monitor(rate=59.94)], []), ("DP-1", "mode")
        )

    def test_rejects_missing_or_incompatible_modes(self):
        for monitors in ([], [monitor(width=1920)], [monitor(rate=75.0)]):
            with self.subTest(monitors=monitors), self.assertRaises(RuntimeError):
                worker.select_display(monitors, [])

    def test_rejects_interlaced_mode(self):
        display = monitor()
        display[1][0][6]["is-interlaced"] = True
        with self.assertRaises(RuntimeError):
            worker.select_display([display], [])

    def test_requires_verified_active_mode(self):
        self.assertTrue(
            worker.display_is_ready([monitor()], [logical()], "DP-1", "mode")
        )
        self.assertFalse(
            worker.display_is_ready(
                [monitor(current=False)], [logical()], "DP-1", "mode"
            )
        )

    def test_rejects_scaling_and_multiple_active_displays(self):
        for layout in ([logical(scale=2.0)], [logical(), logical("DP-2")], []):
            with self.subTest(layout=layout):
                self.assertFalse(
                    worker.display_is_ready([monitor()], layout, "DP-1", "mode")
                )


class WorkerStartupTests(unittest.TestCase):
    def test_refuses_x11_or_missing_wayland_socket(self):
        for environment in (
            {"XDG_SESSION_TYPE": "x11"},
            {"XDG_SESSION_TYPE": "wayland"},
        ):
            with (
                patch.dict(os.environ, environment, clear=True),
                patch.object(worker, "configure_display") as configure,
            ):
                with self.assertRaises(RuntimeError):
                    worker.main()
                configure.assert_not_called()

    def test_display_failure_prevents_worker_start(self):
        with (
            patch.dict(
                os.environ,
                {"XDG_SESSION_TYPE": "wayland", "WAYLAND_DISPLAY": "wayland-0"},
                clear=True,
            ),
            patch.object(
                worker, "configure_display", side_effect=RuntimeError("bad display")
            ),
        ):
            with (
                patch.object(os, "execv") as execute,
                self.assertRaises(RuntimeError),
            ):
                worker.main()
            execute.assert_not_called()

    def test_starts_worker_with_native_wayland_environment(self):
        with (
            patch.dict(
                os.environ,
                {"XDG_SESSION_TYPE": "wayland", "WAYLAND_DISPLAY": "wayland-0"},
                clear=True,
            ),
            patch.object(worker, "configure_display"),
            patch.object(os, "execv") as execute,
        ):
            worker.main()
            self.assertEqual(os.environ["MOZ_ENABLE_WAYLAND"], "1")
            execute.assert_called_once_with(
                "/usr/local/bin/run-start-worker-wrapper.sh",
                ["run-start-worker-wrapper.sh"],
            )


class CompositorTests(unittest.TestCase):
    def run_configure(self, responses, clock=None):
        bus = Mock()
        bus.call_sync.side_effect = responses
        gio = SimpleNamespace(
            bus_get_sync=Mock(return_value=bus),
            BusType=SimpleNamespace(SESSION=0),
            DBusCallFlags=SimpleNamespace(NONE=0),
        )
        # On Ubuntu, use real GLib to validate the D-Bus wire encoding too.
        try:
            from gi.repository import GLib
        except ImportError:
            GLib = SimpleNamespace(
                Error=RuntimeError, Variant=lambda signature, value: (signature, value)
            )
        repository = SimpleNamespace(Gio=gio, GLib=GLib)
        with (
            patch.dict(sys.modules, {"gi.repository": repository}),
            patch.object(worker.time, "sleep"),
            patch.object(worker.time, "monotonic", side_effect=clock or range(100)),
        ):
            worker.configure_display()
        return bus.call_sync.call_args_list

    def test_applies_then_verifies_monitor_configuration(self):
        before = Mock()
        before.unpack.return_value = (7, [monitor(current=False)], [], {})
        applied = Mock()
        after = Mock()
        after.unpack.return_value = (8, [monitor()], [logical()], {})
        calls = self.run_configure([before, applied, after])
        self.assertEqual(
            [call.args[3] for call in calls],
            ["GetCurrentState", "ApplyMonitorsConfig", "GetCurrentState"],
        )
        parameters = calls[1].args[4]
        if hasattr(parameters, "get_type_string"):
            self.assertEqual(
                parameters.get_type_string(), "(uua(iiduba(ssa{sv}))a{sv})"
            )
            parameters = parameters.unpack()
        else:
            parameters = parameters[1]
        self.assertEqual(parameters[0:2], (7, 1))
        self.assertEqual(parameters[2], [(0, 0, 1.0, 0, True, [("DP-1", "mode", {})])])

    def test_already_correct_display_requires_no_changes(self):
        state = Mock()
        state.unpack.return_value = (7, [monitor()], [logical()], {})
        self.assertEqual(len(self.run_configure([state])), 1)

    def test_missing_display_times_out_without_starting_worker(self):
        state = Mock()
        state.unpack.return_value = (7, [], [], {})
        with self.assertRaisesRegex(RuntimeError, "No connected output"):
            self.run_configure([state], clock=[0, 1, 61])


if __name__ == "__main__":
    unittest.main()
