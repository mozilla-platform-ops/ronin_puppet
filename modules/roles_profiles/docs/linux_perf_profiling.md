# System-wide perf recording

`roles_profiles::profiles::linux_perf_profiling` installs `record-system-perf`
for the Talos roles. The existing `/usr/bin/perf` sudo grant remains temporarily
while Firefox's Raptor caller migrates (LS-002).

## Interface

Run `sudo -n /usr/local/bin/record-system-perf` as `cltbld`, with an input pipe
and stdout directed to a file opened by `cltbld`. Keep stdin open throughout
recording; close it to finish. No arguments or input bytes are accepted.
Diagnostics go to stderr. Stdout receives the completed perf data only after
recording succeeds. The caller must check the exit status and discard output
on failure.

The recording options are fixed: system-wide collection, call graphs, monotonic
clock, 1000 Hz, and no build-ID cache updates. Build IDs remain in the recording;
Samply import and symbolication run as the task account. System-wide samples,
including other users' processes, are intentionally preserved.

The wrapper creates a private temporary directory under
`/var/lib/record-system-perf` (root, mode 0700), permits one active invocation,
and limits recordings to 4200 seconds and 8 GiB. EOF or a termination signal
requests SIGINT finalization, with a 30-second grace period. An independent
`timeout` also bounds the collector if the wrapper disappears. Forced termination
can leave a private temporary directory behind; inspect/remove stale directories
only when no recording is active. It does not return a successful profile after
a recording timeout, collector failure, or size-limit failure.

The completed file is opened, its temporary pathname removed, and supplementary
groups/root UID dropped before bytes are delivered to the caller. The task owns
its destination from creation; the wrapper never accepts an output pathname or
changes ownership through a task-controlled path.

## Rollout

1. Deploy this Puppet change, retaining both sudo rules.
2. Deploy the Raptor caller that opens its own output file, starts the wrapper,
   and closes stdin to stop. Keep direct perf for local developer runs.
3. Verify a Linux Speedometer 3 native-profiling task produces a readable profile
   and Samply import succeeds, including subprocess and kernel samples.
4. Remove the original `/usr/bin/perf` grant and its temporary test expectation
   after all callers have migrated. LS-002 remains open until then.

## Checks

```sh
python3 -m unittest discover -s modules/linux_packages/tests -p 'test_record_system_perf.py' -v
pre-commit run --files modules/roles_profiles/manifests/profiles/linux_perf_profiling.pp modules/linux_packages/files/record-system-perf
```

The unit tests exercise boundaries and lifecycle behavior with mocked privilege
operations. Kitchen's Linux perf suite checks the installed ownership, modes,
and sudo rules. A real-worker recording/import is still required to validate the
installed kernel/perf combination; Docker/macOS unit checks cannot establish
profile fidelity or hardware-counter availability.
