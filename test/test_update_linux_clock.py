"""Exercise updater clock handling without SSH, clock changes, or real secrets."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


UPDATER = Path(os.environ.get(
    "CLOCK_TEST_SCRIPT",
    str(Path(__file__).resolve().parents[1] / "provisioners/linux/update_linux.sh"),
))
STUB = r'''
import json
import os
from pathlib import Path
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CLOCK_TEST_CALLS"], "a") as output:
    output.write(json.dumps({"name": name, "args": args}) + "\n")
if name == "ssh" and args[-1] == "sudo /bin/sh -s":
    script = sys.stdin.read().replace("/etc/os-release", '"$CLOCK_TEST_OS_RELEASE"')
    sys.exit(subprocess.run(["/bin/sh"], input=script, text=True).returncode)
if name == "timedatectl":
    if args == ["set-ntp", "true"]:
        sys.exit(int(os.environ.get("CLOCK_TEST_ENABLE_STATUS", "0")))
    if args != ["show", "--property=NTPSynchronized", "--value"]:
        sys.exit(99)
    if os.environ.get("CLOCK_TEST_SHOW_STATUS"):
        sys.exit(int(os.environ["CLOCK_TEST_SHOW_STATUS"]))
    counter = Path(os.environ["CLOCK_TEST_COUNTER"])
    index = int(counter.read_text()) if counter.exists() else 0
    states = os.environ.get("CLOCK_TEST_STATES", "yes").split(",")
    print(states[min(index, len(states) - 1)])
    counter.write_text(str(index + 1))
if name == "ntpd":
    sys.exit(int(os.environ.get("CLOCK_TEST_NTPD_STATUS", "0")))
'''


class ClockTests(unittest.TestCase):
    def run_updater(self, version="24.04", **settings):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "bin"
            binary.mkdir()
            for name in ("ssh", "scp", "timedatectl", "ntpd", "sleep"):
                path = binary / name
                path.write_text("#!" + sys.executable + "\n" + STUB)
                path.chmod(0o755)
            release = root / "os-release"
            release.write_text("ID=ubuntu\nVERSION_ID=" + version + "\n")
            (root / "vault.yaml").write_text("fixture only\n")
            calls = root / "calls.jsonl"
            env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ["PATH"],
                       CLOCK_TEST_OS_RELEASE=str(release), CLOCK_TEST_CALLS=str(calls),
                       CLOCK_TEST_COUNTER=str(root / "counter"), **settings)
            # Point both the master and hardened variants at the fixture Vault.
            script = root / "update.sh"
            source = UPDATER.read_text().replace(
                'SECRETS_FILE="$HOME/vault.yaml"', 'SECRETS_FILE="vault.yaml"')
            script.write_text(source)
            result = subprocess.run(
                ["bash", str(script), "fixture.example.com"], cwd=root,
                env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                timeout=15,
            )
            return result, [json.loads(line) for line in calls.read_text().splitlines()]

    def assert_no_transfer(self, calls):
        # The only remote call must be clock synchronization; no Vault or role action.
        self.assertEqual([call["args"][-1] for call in calls if call["name"] == "ssh"],
                         ["sudo /bin/sh -s"])
        self.assertFalse(any(call["name"] == "scp" for call in calls))

    def test_synchronized_modern_hosts_prefer_timedatectl_without_changes(self):
        for version in ("22.04", "24.04", "26.04"):
            with self.subTest(version=version):
                result, calls = self.run_updater(version)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(any(call["name"] in ("ntpd", "sleep") for call in calls))
                self.assertEqual([call["args"] for call in calls if call["name"] == "timedatectl"],
                                 [["show", "--property=NTPSynchronized", "--value"]])
                self.assertGreater(len([call for call in calls if call["name"] == "ssh"]), 1)

    def test_enables_ntp_and_waits_until_synchronized(self):
        result, calls = self.run_updater(CLOCK_TEST_STATES="no,no,yes")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(call["name"] == "sleep" for call in calls), 2)
        self.assertEqual(sum(call["name"] == "timedatectl" and call["args"] ==
                             ["set-ntp", "true"] for call in calls), 1)
        self.assertFalse(any(call["name"] == "ntpd" for call in calls))

    def test_timeout_stops_before_transfer(self):
        result, calls = self.run_updater(CLOCK_TEST_STATES="no")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not synchronize within 60 seconds", result.stderr)
        self.assertEqual(sum(call["name"] == "sleep" for call in calls), 30)
        self.assert_no_transfer(calls)

    def test_timedatectl_errors_do_not_fall_back_or_transfer(self):
        for settings in ({"CLOCK_TEST_SHOW_STATUS": "1"},
                         {"CLOCK_TEST_STATES": "no", "CLOCK_TEST_ENABLE_STATUS": "1"}):
            with self.subTest(settings=settings):
                result, calls = self.run_updater(**settings)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call["name"] == "ntpd" for call in calls))
                self.assert_no_transfer(calls)

    def test_older_hosts_keep_ntpd(self):
        for version in ("18.04", "20.04"):
            with self.subTest(version=version):
                result, calls = self.run_updater(version)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([call["args"] for call in calls if call["name"] == "ntpd"],
                                 [["-q", "-g"]])
                self.assertFalse(any(call["name"] == "timedatectl" for call in calls))

    def test_ntpd_failure_stops_before_transfer(self):
        result, calls = self.run_updater("20.04", CLOCK_TEST_NTPD_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_transfer(calls)


if __name__ == "__main__":
    unittest.main()
