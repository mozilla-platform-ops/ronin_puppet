# Lifecycle tools

- [collect-lifecycle-logs.py](collect-lifecycle-logs.py) collects host lifecycle
  logs over SSH into timestamped snapshots.
- [analyze-lifecycle-logs.py](analyze-lifecycle-logs.py) analyzes collected logs
  and produces terminal, JSON, or CSV reports.

See the [lifecycle design](../docs/test_host_lifecycle_timing_design.md) for the
event model and measurement definitions. Run either script with `--help` for
its command-line options.

## Running tests

From the repository root, run all collector and analyzer tests:

```sh
python3 -m unittest discover -s tools/tests -v
```

The tools and tests use Python 3's standard library; no additional packages
are required. Tests use temporary files and mocked collection calls, without
connecting to workers or requiring real host logs.

To run one suite:

```sh
python3 -m unittest discover -s tools/tests -p 'test_collect_lifecycle_logs.py' -v
python3 -m unittest discover -s tools/tests -p 'test_analyze_lifecycle_logs.py' -v
```
