import importlib.machinery
import importlib.util
import os
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).parents[1] / "files" / "netperf-tc"
loader = importlib.machinery.SourceFileLoader("netperf_tc", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
netperf_tc = importlib.util.module_from_spec(spec)
loader.exec_module(netperf_tc)


class NetperfTcTests(unittest.TestCase):
    def test_rejects_command_and_option_injection(self):
        attacks = (
            ("1;id", "1", "0", "tcp", "80"),
            ("1", "1$(id)", "0", "tcp", "80"),
            ("1", "1", "0 --help", "tcp", "80"),
            ("1", "1", "0", "tcp;id", "80"),
            ("1", "1", "0", "tcp", "80 --help"),
            ("1", "1", "0", "tcp", "-1"),
        )
        for arguments in attacks:
            with self.subTest(arguments=arguments), mock.patch.object(
                netperf_tc, "tc"
            ) as tc:
                self.assertEqual(netperf_tc.apply(*arguments), 2)
                tc.assert_not_called()

    def test_uses_fixed_environment_for_root_tc_commands(self):
        with mock.patch.dict(os.environ, {"TC_CONFIG": "/task/config"}):
            with mock.patch.object(netperf_tc.subprocess, "run") as run:
                netperf_tc.reset()
        args, kwargs = run.call_args
        self.assertEqual(args[0], [netperf_tc.TC, "qdisc", "del", "dev", "lo", "root"])
        self.assertEqual(kwargs["env"], netperf_tc.ENV)
        self.assertEqual(kwargs["cwd"], "/")
        self.assertNotIn("TC_CONFIG", kwargs["env"])

    def test_validated_values_are_passed_as_individual_arguments(self):
        with mock.patch.object(netperf_tc, "reset"):
            with mock.patch.object(netperf_tc, "tc") as tc:
                self.assertEqual(netperf_tc.apply("100", "10", "0.5", "tcp", "443"), 0)
        for call in tc.call_args_list:
            self.assertTrue(all(isinstance(argument, str) for argument in call.args))
            self.assertTrue(
                all(
                    not any(character in argument for character in ";$`()\n")
                    for argument in call.args
                )
            )


if __name__ == "__main__":
    unittest.main()
