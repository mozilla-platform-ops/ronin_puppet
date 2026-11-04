Run the summary fixtures with `bash test_gwhc.sh` from this directory. Process
and operator-hold tests run from the repository root with
`python3 -m unittest discover -s test -p 'test_gwhc_processes.py'`.

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
