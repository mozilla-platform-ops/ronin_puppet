"""Exercise the installed wrapper with a fake collector in a disposable container."""

import os
import pwd
import shutil
import subprocess
import sys
import time
from pathlib import Path


def main():
    if not Path("/.dockerenv").exists() or os.geteuid() != 0:
        raise RuntimeError("run only as root in a disposable Docker container")
    subprocess.run(["useradd", "-m", "cltbld"], check=True)
    account = pwd.getpwnam("cltbld")
    state = Path("/var/lib/record-system-perf")
    state.mkdir(mode=0o700)
    wrapper = Path("/usr/local/bin/record-system-perf")
    shutil.copyfile(Path(__file__).parents[1] / "files/record-system-perf", wrapper)
    wrapper.chmod(0o755)
    Path("/usr/bin/perf").write_text(
        "#!" + sys.executable + "\n"
        "import os, pathlib, signal, sys, time\n"
        "assert os.geteuid() == 0\n"
        "assert os.environ['PERF_CONFIG'] == '/dev/null'\n"
        "assert os.environ['HOME'] == '/root'\n"
        "assert sys.argv[1:-1] == ['record', '-a', '-g', '-k', 'mono', '-F', '1000', '--no-buildid-cache', '-o']\n"
        "done = False\n"
        "def stop(*args):\n"
        "    global done\n"
        "    done = True\n"
        "signal.signal(signal.SIGINT, stop)\n"
        "pathlib.Path('/var/lib/record-system-perf/ready').touch()\n"
        "while not done: time.sleep(0.02)\n"
        "pathlib.Path(sys.argv[-1]).write_bytes(b'PERFILE2-fixture')\n"
    )
    Path("/usr/bin/perf").chmod(0o755)
    env = dict(
        os.environ,
        SUDO_UID=str(account.pw_uid),
        HOME="/home/cltbld",
        PERF_CONFIG="/home/cltbld/.perfconfig",
        PYTHONPATH="/home/cltbld",
    )
    command = [sys.executable, "-I", str(wrapper)]
    assert (
        subprocess.run(
            command + ["-o", "/etc/passwd"], env=env, capture_output=True
        ).returncode
        != 0
    )
    process = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    try:
        deadline = time.monotonic() + 10
        while not (state / "ready").exists():
            if process.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("collector did not start")
            time.sleep(0.05)
        second = subprocess.run(
            command, input=b"", capture_output=True, env=env, timeout=5
        )
        assert second.returncode != 0, "concurrent recording must be rejected"
        # communicate closes stdin, requesting finalization without signaling sudo.
        output, errors = process.communicate(timeout=10)
        assert process.returncode == 0, errors.decode()
        assert output == b"PERFILE2-fixture", (output, errors)
        assert sorted(p.name for p in state.iterdir()) == ["ready"]
        print(
            "PASS: Linux root collection, EOF/SIGINT forwarding through timeout, exclusive lock, cleanup and data delivery"
        )
        # Deliver to a file opened as the actual task identity, as Raptor does.
        dest = Path("/home/cltbld/profile.data")
        script = "from pathlib import Path; import sys; Path(sys.argv[1]).write_bytes(sys.stdin.buffer.read())"

        def task_identity():
            os.setgroups([])
            os.setgid(account.pw_gid)
            os.setuid(account.pw_uid)

        subprocess.run(
            [sys.executable, "-c", script, str(dest)],
            input=output,
            preexec_fn=task_identity,
            check=True,
        )
        assert dest.stat().st_uid == account.pw_uid
        subprocess.run(
            [
                sys.executable,
                "-c",
                "import pathlib,sys; assert pathlib.Path(sys.argv[1]).read_bytes() == b'PERFILE2-fixture'",
                str(dest),
            ],
            preexec_fn=task_identity,
            check=True,
        )
        print("PASS: cltbld owns and can read the delivered profile")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


if __name__ == "__main__":
    main()
