# Test Host Lifecycle Timing Design

## Goal

Measure where time is spent on Taskcluster test hosts, especially the
time *outside* of task execution. The initial implementation favors
simplicity and local data collection over centralized metrics.

## Initial Approach

Instead of integrating directly with Prometheus or InfluxDB, each host
will maintain a local append-only event log.

The logs will be collected later over SSH for offline analysis. This
allows the event model and analysis to mature before introducing
centralized ingestion.

## Design Principles

-   Record facts, not derived state.
-   Emit lifecycle events as they occur.
-   Keep the logging wrapper simple.
-   Compute durations during analysis rather than on the host.
-   Prefer explicit hooks over inference.
-   Fall back to log scanning only where no explicit signal exists.

## Event Logger

A small Python wrapper/library will be responsible for writing
structured lifecycle events.

Recommended format:

``` json
{
  "timestamp": "2026-08-05T23:03:14Z",
  "event": "task_finished",
  "task_id": "...",
  "source": "generic-worker"
}
```

JSON Lines (one JSON object per line) is preferred because it is easy to
append, parse, and extend.

## Initial Events

The following events should be emitted where possible:

-   task_started
-   task_finished
-   cleanup_started
-   cleanup_finished
-   drain_started
-   reboot_requested
-   boot_completed
-   worker_ready

Additional events can be added later without changing the analysis
model.

## Hook Locations

### Task Started

Currently there is no explicit signal from generic-worker.

Initial implementation:

-   Scan generic-worker logs or status output after task completion to
    recover the task_started timestamp.

Future improvement:

-   Work with the Taskcluster team to expose task_started directly via a
    status file or explicit lifecycle event.

### Task Finished

This is a natural hook because generic-worker exits and the existing
wrapper script takes control.

The wrapper should:

1.  Read any available task timing information.
2.  Emit a task_finished event.
3.  Continue logging subsequent lifecycle events.

### Cleanup

Emit cleanup_started and cleanup_finished around any host cleanup
activities.

### Reboot

Emit reboot_requested immediately before initiating a reboot.

### Boot

During boot, emit:

-   boot_completed when userspace reaches the desired initialization
    point.
-   worker_ready once the worker is capable of accepting new work.

## Data Collection

Initially:

-   SSH into hosts.
-   Collect the append-only event logs.
-   Merge and analyze them offline.

No centralized metrics infrastructure is required for the first
implementation.

## Analysis

Durations are computed by subtracting adjacent event timestamps.

Examples:

-   task_started -\> task_finished = task runtime
-   task_finished -\> cleanup_started = handoff latency
-   cleanup_started -\> reboot_requested = cleanup duration
-   reboot_requested -\> boot_completed = reboot duration
-   boot_completed -\> worker_ready = worker initialization
-   worker_ready -\> task_started = idle time

## Future Enhancements

Once the event model is validated:

-   Feed events into InfluxDB.
-   Build Grafana dashboards.
-   Alert on excessive phase durations.
-   Replace inferred events with explicit lifecycle notifications from
    generic-worker.
