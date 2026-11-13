Run the summary fixtures with `bash test_gwhc.sh` from this directory. Process
and operator-hold tests run from the repository root with
`python3 -m unittest discover -s test -p 'test_gwhc_processes.py'`.

Live `gwhc --json` reports contain `schema_version: 1`, an integer identifying
the JSON contract rather than the software release. Consumers should ignore
additional fields; incompatible changes to documented fields require a new
schema version. Reports without a version are legacy and do not establish
that zombie detection ran. Replay preserves the snapshot's version, including
its absence, because it does not perform fresh checks.

In version 1, the `generic_worker_process` check's `data.zombie_pids` is an
array of confirmed zombie generic-worker PIDs. `data.processes` records each
verified matching process as an object with integer `pid` and `ppid` and a
Linux process `state` string; `Z` identifies a zombie. A nonempty `zombie_pids`
is positive zombie evidence and the check fails. An empty array is not proof of
health if process inspection failed: consult the check status and any
`data.unverified_pids`. Missing or malformed evidence and unsupported schema
versions must be treated as unverified. Summary state and exit status alone do
not identify the cause of a failure.

`gwhc` reports `HELD` when `/home/cltbld/operator_hold` is a regular file,
matching the worker startup wrapper. It only observes the hold; it never creates
or clears it. The `operator_hold` check records `data.active` (boolean) and
`data.path` in JSON. Replaying a snapshot uses that recorded state.

Automated recovery consumers must skip hosts whose `state` is `HELD` or whose
`operator_hold` check has `data.active: true`, including when `ok` is false or
the command exits with status 1. `HELD` takes precedence over every other summary
state, including task activity. A hold does not stop an already running task.

Individual health checks still run and retain their results. Exit status remains
0 when all checks pass or warn, and 1 when any check fails. For example, a held
host with no generic-worker process reports `HELD`, a failing process check,
`ok: false`, and exit status 1. A held host with a healthy running worker reports
`HELD`, `ok: true`, and exit status 0. `HELD` describes operator intent, not health.
