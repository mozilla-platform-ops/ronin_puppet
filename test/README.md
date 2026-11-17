# Tests

This directory contains focused regression tests and full-system integration
tests. Run commands below from the repository root.

## Lightweight shell tests

These exercise selected script functions with temporary files, local Git
repositories or mocked external commands. They cover failure paths cheaply and
precisely, without provisioning a worker or applying a Puppet catalog. They do
not require root, production credentials or access to fleet hosts.

| Command | Purpose |
| --- | --- |
| `bash test/test_run_puppet_git_recovery.sh` | Reproduce empty remote refs, verify safe recovery and GC-log archival, protect locks and unrelated refs. Also runs the auth-fallback suite. |
| `bash test/test_run_puppet_git_auth.sh` | Check public/private repository authentication fallback and explicitly selected authentication modes. Can also run independently. |
| `bash test/test_bootstrap_linux.sh` | Check checkout preparation, Puppet apply retries and orderly reboot handoff using mocks. |
| `bash test/test_bootstrap_bitbar_release.sh` | Check exact release-package selection, failed downloads/installations and temporary staging cleanup using mocks. |

Use Bash and Git; the Linux bootstrap test also needs Python 3 and standard Unix
tools. These tests run as explicitly named steps in the Pre-commit GitHub Actions
workflow on its Ubuntu runner. The recovery suite invokes auth tests, so CI does
not run the auth script a second time. There is no automatic directory-wide
shell-script execution and no additional local pre-commit hook.

## Container service tests

`docker/snmpd-permissions/` tests a real SNMP daemon in disposable Ubuntu 24.04:

```bash
bash test/docker/snmpd-permissions/run.sh
```

The runner requires Docker with a running daemon. Building the image downloads
Ubuntu packages. It builds from the repository root, then runs the test in a
fresh container that is removed on exit; the image remains available locally.
It does not mount the host filesystem or require a privileged container.

The test creates a fixture task user, checks that the user cannot read SNMP
community configuration, verifies daemon access and privilege dropping, and
checks real queries after configuration reload and restart. It runs as root
inside the container and modifies its users and `/etc`; do not run `test.sh`
directly on your workstation or a fleet host. Only fixture communities are used.
The Pre-commit workflow runs this in a separate **SNMP daemon permissions** job.

## Kitchen integration tests

[`integration/`](integration/README.md) contains InSpec, Serverspec and Pester
checks used by Kitchen. Kitchen provisions an environment, applies the Puppet
catalog and checks the resulting system. This verifies installation, resource
ordering and integration that isolated script tests cannot establish.

For example:

```bash
./bin/kitchen_docker test linux-perf-ubuntu-2404
```

The focused script tests complement Kitchen: a successful mocked retry test
does not establish that a real catalog converges, and a successful catalog run
does not exercise every recovery or authentication failure path.

## Other focused tests

Top-level `test_*.py`, `test_*.rb` and `.ps1` files cover individual helpers,
catalog properties and platform-specific behavior. Their dependencies vary;
read each test's header and the relevant workflow before running it. For a
Python unittest module, for example:

```bash
python3 -m unittest discover -s test -p test_puppet_run_marker.py
```

Files in `.github/scripts/` also include workflow-specific regression suites.
Kitchen converge retry and reprovision-runner tests are already invoked by
their existing path-filtered pre-commit hooks. Presence in `test/` alone does
not imply that a test is automatically executed in CI.
