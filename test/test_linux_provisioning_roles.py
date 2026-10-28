"""Run provisioning scripts with fake SSH; never touch real hosts or secrets."""

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

REPO = pathlib.Path(__file__).parents[1]
STUB = '''
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
data = sys.stdin.read() if name == "ssh" else ""
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps({"name": name, "args": args, "stdin": data}) + "\\n")
if name == "ssh-keyscan":
    print("fixture-host-key")
elif name == "ssh":
    command = args[-1]
    if command == "test -e /etc/puppet_role":
        sys.exit(1)
    if command == "sudo cat /etc/puppet_role || true":
        print(os.environ.get("TEST_CURRENT_ROLE", "old_role"))
    elif command == "sudo /usr/bin/tee /etc/puppet_role >/dev/null":
        # Execute the same fixed tee command locally, changing only its path.
        result = subprocess.run(["sh", "-c", '/usr/bin/tee "$TEST_ROLE_PATH" >/dev/null'],
                                input=data, universal_newlines=True)
        sys.exit(result.returncode)
sys.exit(0)
'''


class RoleTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("ssh", "scp", "ssh-keygen", "ssh-keyscan", "sleep"):
            script = self.bin / name
            script.write_text("#!" + sys.executable + "\n" + STUB)
            script.chmod(0o755)
        self.vault = self.root / "vault.yaml"
        self.vault.write_text("fixture secrets\n")
        (self.root / "bootstrap_linux.sh").write_text("fixture bootstrap\n")
        self.calls = self.root / "calls.jsonl"
        self.role = self.root / "puppet_role"
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        TEST_CALLS=str(self.calls), TEST_ROLE_PATH=str(self.role),
                        TEST_VAULT=str(self.vault), TEST_KNOWN_HOSTS=str(self.root / "known_hosts"))

    def run_script(self, name, arguments, current="old_role"):
        source = (REPO / "provisioners/linux" / name).read_text()
        # Replace only local fixture paths; preserve argument checks and remote
        # commands. Do not redirect HOME or touch an operator's actual files.
        source = source.replace('SECRETS_FILE="$HOME/vault.yaml"', 'SECRETS_FILE="$TEST_VAULT"')
        source = source.replace('>> ~/.ssh/known_hosts', '>> "$TEST_KNOWN_HOSTS"')
        script = self.root / name
        script.write_text(source)
        self.calls.unlink(missing_ok=True)
        self.role.unlink(missing_ok=True)
        result = subprocess.run(["bash", str(script)] + arguments, cwd=self.root,
                                env=dict(self.env, TEST_CURRENT_ROLE=current),
                                stdin=subprocess.DEVNULL, capture_output=True, text=True)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []
        return result, calls

    def test_invalid_roles_rejected_before_any_remote_actions(self):
        for name in ("deliver_linux.sh", "update_linux.sh"):
            for role in ("bad;touch injected", "bad$(touch injected)", "bad`touch injected`", "bad|cat",
                         "bad&cat", "bad'role", 'bad"role', "bad\nrole", "bad\rrole", "bad role",
                         "bad/role", "../role", "-role", "_role", "9role", "ROLE", "rôle"):
                with self.subTest(script=name, role=role):
                    result, calls = self.run_script(name, ["test.example.com", role, "force"])
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(calls, [])
                    self.assertFalse(self.role.exists())
                    self.assertFalse((self.root / "injected").exists())

    def test_valid_roles_are_stdin_data_to_fixed_command(self):
        for name in ("deliver_linux.sh", "update_linux.sh"):
            for role in ("gecko_t_linux_talos", "gecko_t_linux_2404_talos", "bitbar_devicepool"):
                with self.subTest(script=name, role=role):
                    result, calls = self.run_script(name, ["test.example.com", role, "force"])
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(self.role.read_bytes(), (role + "\n").encode())
                    writes = [call for call in calls if call["name"] == "ssh" and "/usr/bin/tee" in call["args"][-1]]
                    self.assertEqual(len(writes), 1)
                    self.assertEqual(writes[0]["args"][-1], "sudo /usr/bin/tee /etc/puppet_role >/dev/null")
                    self.assertEqual(writes[0]["stdin"], role + "\n")
                    for call in calls:
                        self.assertNotIn(role, " ".join(call["args"]))

    def test_optional_role_and_force_behavior_are_preserved(self):
        result, calls = self.run_script("update_linux.sh", ["test.example.com"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(calls)
        self.assertFalse(self.role.exists())
        role = "gecko_t_linux_talos"
        result, _ = self.run_script("update_linux.sh", ["test.example.com", role])
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.role.exists())
        result, _ = self.run_script("update_linux.sh", ["test.example.com", role], current=role)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.role.exists())
        result, calls = self.run_script("deliver_linux.sh", ["test.example.com"])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
