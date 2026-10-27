"""Exercise PAT handling with real Git and fake credentials; never use GitHub."""

import base64
import http.server
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse

TEMPLATE = pathlib.Path(__file__).parents[1] / "modules/puppet/templates/puppet-ubuntu-run-puppet.sh.erb"
TOKEN = "F29_FAKE_TOKEN"
USER = "F29_FAKE_USER"
HEADER = "Authorization: Basic " + base64.b64encode((USER + ":" + TOKEN).encode()).decode()
FUNCTION_NAMES = (
    "fail", "require_root_owned_directory", "protect_git_metadata", "clear_git_pat_auth",
    "require_secure_working_dir", "configure_git_pat_auth", "configure_deploy_key_auth",
    "configure_pat_auth", "configure_public_anonymous_auth", "configure_git_remote",
    "fetch_puppet_remote", "configure_git_auth", "init_git_working_dir", "reinit_working_dir",
)
SOURCE = TEMPLATE.read_text(encoding="utf-8")
FUNCTIONS = "\n".join(re.search(r"^function " + name + r" \{.*?^\}", SOURCE, re.M | re.S).group()
                      for name in FUNCTION_NAMES)


class PatTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name)
        self.work = self.root / "code"
        self.work.mkdir(mode=0o755)
        self.remote = self.root / "remote.git"
        subprocess.run(["git", "init", "--bare", str(self.remote)], stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, check=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.real_git = shutil.which("git")
        self.calls = self.root / "calls.jsonl"
        # Record only fake credential usage in private test fixtures. Assert the
        # real Git parser accepts the environment without printing its value.
        wrapper = self.bin / "git"
        wrapper.write_text('#!' + sys.executable + '\n' + '''
import json, os, subprocess, sys
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps({"args": sys.argv[1:], "parameters": os.environ.get("GIT_CONFIG_PARAMETERS"),
                          "header_exported": "GIT_PAT_HEADER" in os.environ,
                          "traces": [key for key in os.environ if key.startswith("GIT_TRACE") or key == "GIT_CURL_VERBOSE"]}) + "\\n")
if "fetch" in sys.argv:
    if os.environ.get("GIT_CONFIG_PARAMETERS"):
        result = subprocess.run([os.environ["TEST_GIT"], "config", "--get-urlmatch", "http.extraHeader", os.environ.get("TEST_MATCH_URL", "https://github.com/mozilla-platform-ops/ronin_puppet.git")],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        if result.returncode or result.stdout.strip() != os.environ["TEST_HEADER"]:
            sys.exit("Git did not receive the expected temporary header")
    if os.environ.get("TEST_FAIL_FETCH") == "1":
        sys.exit(1)
os.execv(os.environ["TEST_GIT"], [os.environ["TEST_GIT"]] + sys.argv[1:])
''')
        wrapper.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        WORKING_DIR=str(self.work), TEST_CALLS=str(self.calls),
                        TEST_GIT=self.real_git, TEST_HEADER=HEADER, TEST_REMOTE=str(self.remote))
        self.prelude = FUNCTIONS + '''
cd "$WORKING_DIR" || exit 1
YQ_PRESENT=1
YQ_BIN=fake_yq
fake_yq() {
    case "$1" in
        .github.pat) printf 'F29_FAKE_TOKEN\\n' ;;
        .github.pat_user) printf 'F29_FAKE_USER\\n' ;;
        *) return 1 ;;
    esac
}
GIT_REMOTE_URL=$TEST_REMOTE
GIT_AUTH_MODE_SELECTED=pat
PUPPET_REPO=https://github.com/mozilla-platform-ops/ronin_puppet.git
deploy_key_is_available() { [ "${TEST_DEPLOY_KEY:-0}" = 1 ]; }
GITHUB_DEPLOY_KEY_PATH=/root/.ssh/fake_key
GITHUB_KNOWN_HOSTS_PATH=/root/.ssh/fake_known_hosts
'''
        if os.getuid() != 0 or sys.platform != "linux":
            # Local macOS fixtures simulate root ownership, retaining real
            # filesystem type/mode/link-count checks. Containers use real stat.
            stat_script = self.root / "fixture-stat.py"
            stat_script.write_text('''import os, stat, sys
info = os.lstat(sys.argv[2])
values = {"%u": 0, "%g": 0, "%h": info.st_nlink, "%a": format(stat.S_IMODE(info.st_mode), "o")}
print(values[sys.argv[1]])
''')
            self.env["TEST_PYTHON"] = sys.executable
            self.env["TEST_STAT"] = str(stat_script)
            self.prelude += 'stat() { "$TEST_PYTHON" "$TEST_STAT" "$2" "$3"; }\n'

    def run_shell(self, commands, success=True, **env):
        result = subprocess.run(["bash", "-c", self.prelude + commands],
                                env=dict(self.env, **env), stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, universal_newlines=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        for secret in (TOKEN, USER, HEADER.split()[-1]):
            self.assertNotIn(secret, result.stdout + result.stderr)
        return result

    def check_metadata(self):
        self.assertEqual((self.work / ".git").stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.work / ".git/config").stat().st_mode & 0o777, 0o600)
        self.assertNotIn("extraheader", (self.work / ".git/config").read_text().lower())
        self.assertNotIn(TOKEN, (self.work / ".git/config").read_text())

    def test_initialization_reinitialization_and_fetch_failure(self):
        self.run_shell('''
init_git_working_dir || exit 1
fetch_puppet_remote || exit 1
TEST_FAIL_FETCH=1 fetch_puppet_remote && exit 2
reinit_working_dir || exit 1
fetch_puppet_remote || exit 1
# Metadata creation must not change the parent umask for checkout/Puppet files.
touch public-file
''')
        self.check_metadata()
        self.assertTrue((self.work / "public-file").stat().st_mode & 0o044)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        fetches = [call for call in calls if "fetch" in call["args"]]
        self.assertEqual(len(fetches), 3)
        self.assertTrue(all(call["parameters"] and HEADER in call["parameters"] for call in fetches))
        for call in calls:
            self.assertFalse(call["header_exported"])
            self.assertNotIn(HEADER.split()[-1], " ".join(call["args"]))
            if "fetch" not in call["args"]:
                self.assertIsNone(call["parameters"])

    def test_legacy_header_cleanup_and_disabled_or_missing_credentials(self):
        for setup in ('', 'SKIP_GH_PAT_AUTH=1', 'YQ_PRESENT=0', 'fake_yq() { :; }'):
            with self.subTest(setup=setup):
                shutil.rmtree(self.work)
                self.work.mkdir()
                self.run_shell('init_git_working_dir')
                subprocess.run([self.real_git, "-C", str(self.work), "config", "http.https://github.com/.extraHeader", HEADER], check=True)
                (self.work / ".git").chmod(0o755)
                (self.work / ".git/config").chmod(0o644)
                self.run_shell(setup + '\nconfigure_git_pat_auth\n')
                self.check_metadata()

    def test_auto_forced_pat_deploy_key_and_anonymous_modes(self):
        self.run_shell('''
init_git_working_dir || exit 1
RUN_PUPPET_GIT_AUTH_MODE=pat configure_git_auth || exit 1
[ -n "$GIT_PAT_HEADER" ] || exit 1
RUN_PUPPET_GIT_AUTH_MODE=auto configure_git_auth || exit 1
[ "$GIT_AUTH_MODE_SELECTED" = pat ] || exit 1
TEST_DEPLOY_KEY=1 RUN_PUPPET_GIT_AUTH_MODE=auto configure_git_auth || exit 1
[ "$GIT_AUTH_MODE_SELECTED" = deploy-key ] && [ -z "$GIT_PAT_HEADER" ] || exit 1
RUN_PUPPET_GIT_AUTH_MODE=deploy-key TEST_DEPLOY_KEY=1 configure_git_auth || exit 1
configure_pat_auth || exit 1
configure_public_anonymous_auth || exit 1
[ "$GIT_AUTH_MODE_SELECTED" = anonymous ] && [ -z "$GIT_PAT_HEADER" ] || exit 1
PUPPET_REPO=https://github.com/mozilla-platform-ops/ronin_puppet-private.git
configure_public_anonymous_auth && exit 2
exit 0
''')
        self.check_metadata()

    def test_fetch_disables_tracing_and_does_not_export_header(self):
        self.run_shell('''
init_git_working_dir || exit 1
export GIT_TRACE=1 GIT_TRACE_CURL=1 GIT_CURL_VERBOSE=1 GIT_TRACE2=1
fetch_puppet_remote || exit 1
''')
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual([call for call in calls if "fetch" in call["args"]][0]["traces"], [])

    def test_forced_anonymous_rejects_other_repositories_before_git_changes(self):
        self.run_shell('init_git_working_dir || exit 1')
        before = (self.work / '.git/config').read_bytes()
        self.calls.write_text('')
        for repo in ('https://github.com/mozilla-platform-ops/ronin_puppet-private.git',
                     'https://github.com/aerickson/ronin_puppet-private.git',
                     'https://github.com/other/public.git',
                     'https://github.com/mozilla-platform-ops/ronin_puppet.git/'):
            with self.subTest(repo=repo):
                result = self.run_shell('PUPPET_REPO=$TEST_REPO\nRUN_PUPPET_GIT_AUTH_MODE=anonymous configure_git_auth',
                                        success=False, TEST_REPO=repo)
                self.assertIn('only supported for the public', result.stderr)
                self.assertEqual((self.work / '.git/config').read_bytes(), before)
                self.assertEqual(self.calls.read_text(), '')

    def test_forced_anonymous_http_fetch_ignores_available_credentials(self):
        subprocess.run([self.real_git, '--git-dir', str(self.remote), 'update-server-info'], check=True)
        requests = []
        root = self.root

        class AnonymousServer(http.server.SimpleHTTPRequestHandler):
            def translate_path(self, path):
                return str(root / urllib.parse.urlsplit(path).path.lstrip('/'))

            def log_message(self, *_args):
                pass

            def do_GET(self):
                requests.append(self.headers.get('Authorization'))
                super().do_GET()

        server = http.server.HTTPServer(('127.0.0.1', 0), AnonymousServer)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            scope = 'http.http://127.0.0.1:{}/.extraHeader'.format(server.server_port)
            global_config = self.root / 'global-config'
            subprocess.run([self.real_git, 'config', '--file', str(global_config), scope, HEADER], check=True)
            subprocess.run([self.real_git, 'config', '--file', str(global_config), 'credential.helper', '!exit 99'], check=True)
            self.run_shell('init_git_working_dir || exit 1')
            subprocess.run([self.real_git, '-C', str(self.work), 'config', 'http.https://github.com/.extraHeader', HEADER], check=True)
            # Adapt only fetch's header reset to the loopback server. Selection
            # and legacy config cleanup still use the production GitHub URL.
            original = self.prelude
            fetch_function = re.search(r'^function fetch_puppet_remote \{.*?^\}', original, re.M | re.S).group()
            self.prelude = original.replace(fetch_function, fetch_function.replace('http.https://github.com/.extraHeader', scope))
            try:
                result = self.run_shell('''
fake_yq() { echo 'Unexpected credential lookup' >&2; return 99; }
export GIT_SSH_COMMAND=/bin/false
GIT_PAT_HEADER=stale-header
TEST_DEPLOY_KEY=1 RUN_PUPPET_GIT_AUTH_MODE=anonymous configure_git_auth || exit 1
[ "$GIT_AUTH_MODE_SELECTED" = anonymous ] && [ -z "$GIT_PAT_HEADER" ] || exit 1
[ -z "${GIT_SSH_COMMAND+x}" ] || exit 1
git remote set-url origin "$TEST_HTTP_REMOTE" || exit 1
fetch_puppet_remote || exit 1
''', GIT_CONFIG_GLOBAL=str(global_config), TEST_HTTP_REMOTE='http://127.0.0.1:{}/remote.git'.format(server.server_port))
                self.assertIn('Git authentication: anonymous', result.stdout)
                self.assertNotIn('Unexpected credential lookup', result.stderr)
            finally:
                self.prelude = original
            self.assertTrue(requests)
            self.assertTrue(all(header is None for header in requests))
            self.check_metadata()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_real_http_fetch_authenticates_without_persisting_credentials(self):
        seed = self.root / "seed"
        seed.mkdir()
        for args in (["init", str(seed)], ["-C", str(seed), "add", "."],
                     ["-C", str(seed), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--allow-empty", "-m", "fixture"],
                     ["-C", str(seed), "push", str(self.remote), "HEAD:refs/heads/master"],
                     ["--git-dir", str(self.remote), "update-server-info"]):
            subprocess.run([self.real_git] + args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        requests = []
        root = self.root

        class AuthServer(http.server.SimpleHTTPRequestHandler):
            def translate_path(self, path):
                return str(root / urllib.parse.urlsplit(path).path.lstrip("/"))

            def log_message(self, *_args):
                pass

            def do_GET(self):
                authorized = self.headers.get("Authorization") == HEADER.split(": ", 1)[1]
                requests.append(authorized)
                if not authorized:
                    self.send_response(401)
                    self.end_headers()
                    return
                super().do_GET()

        server = http.server.HTTPServer(("127.0.0.1", 0), AuthServer)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = "http://127.0.0.1:{}/remote.git".format(server.server_port)
            # Change only the fetch header's URL scope to the loopback fixture.
            # Other tests verify the production GitHub URL through real Git.
            original = self.prelude
            self.prelude = original.replace("http.https://github.com/.extraHeader=", "http.http://127.0.0.1:{}/.extraHeader=".format(server.server_port))
            try:
                self.run_shell('GIT_REMOTE_URL=$TEST_MATCH_URL\ninit_git_working_dir || exit 1\nfetch_puppet_remote || exit 1', TEST_MATCH_URL=url)
            finally:
                self.prelude = original
            self.assertTrue(requests)
            self.assertTrue(all(requests))
            self.check_metadata()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_unsafe_metadata_is_rejected_without_modifying_link_target(self):
        for attack in ("config_symlink", "config_hardlink", "config_directory", "config_writable", "git_symlink", "git_writable"):
            with self.subTest(attack=attack):
                shutil.rmtree(self.work)
                self.work.mkdir()
                self.run_shell('init_git_working_dir')
                target = self.root / "target"
                target.write_text("must stay unchanged")
                target.chmod(0o644)
                config = self.work / ".git/config"
                if attack in ("config_symlink", "config_hardlink", "config_directory"):
                    config.unlink()
                    if attack == "config_symlink":
                        config.symlink_to(target)
                    elif attack == "config_hardlink":
                        os.link(target, config)
                    else:
                        config.mkdir()
                elif attack == "config_writable":
                    config.chmod(0o666)
                elif attack == "git_symlink":
                    shutil.rmtree(self.work / ".git")
                    (self.work / ".git").symlink_to(self.remote, target_is_directory=True)
                else:
                    (self.work / ".git").chmod(0o777)
                self.run_shell('configure_git_pat_auth', success=False)
                self.assertEqual(target.read_text(), "must stay unchanged")
                self.assertEqual(target.stat().st_mode & 0o777, 0o644)

    @unittest.skipUnless(os.getuid() == 0 and sys.platform == "linux", "requires root Linux container")
    def test_real_foreign_metadata_ownership_is_rejected(self):
        for name in (".git", ".git/config"):
            for uid, gid in ((65534, 0), (0, 65534)):
                with self.subTest(name=name, uid=uid, gid=gid):
                    shutil.rmtree(self.work)
                    self.work.mkdir()
                    self.run_shell('init_git_working_dir')
                    os.chown(self.work / name, uid, gid)
                    self.run_shell('configure_git_pat_auth', success=False)

    @unittest.skipUnless(os.getuid() == 0 and sys.platform == "linux", "requires root Linux container")
    def test_real_task_uid_cannot_read_legacy_metadata(self):
        self.root.chmod(0o755)
        self.run_shell('init_git_working_dir')
        subprocess.run([self.real_git, "-C", str(self.work), "config", "http.https://github.com/.extraHeader", HEADER], check=True)
        self.run_shell('protect_git_metadata\nrequire_secure_working_dir')
        parent_environment = pathlib.Path("/proc/{}/environ".format(os.getpid()))
        pid = os.fork()
        if pid == 0:
            os.setgroups([])
            os.setgid(65534)
            os.setuid(65534)
            for path in (self.work / ".git/config", parent_environment):
                try:
                    path.read_bytes()
                except PermissionError:
                    continue
                os._exit(1)
            os._exit(0)
        _, status = os.waitpid(pid, 0)
        self.assertEqual(status, 0)


if __name__ == "__main__":
    unittest.main()
