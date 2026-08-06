# Linux Test Host Lifecycle Timing Design

## Goal

Measure where time is spent on Linux Taskcluster test hosts, especially
time outside task execution. The first implementation favors local data
collection and offline analysis over centralized metrics.

The initial scope is deliberately limited to the normal single-task Linux
worker lifecycle. Other platforms and centralized ingestion can use the
validated event model later.

## Approach

Each host maintains a local append-only JSON Lines event log. Logs are
collected over SSH and merged for offline analysis.

The design records facts, rather than durations or conclusions. Analysis
computes durations and identifies incomplete lifecycles after collection.

## Event Model

Every event contains these common fields:

```json
{
  "schema_version": 1,
  "event": "worker_started",
  "recorded_at": "2026-08-05T23:03:14.123Z",
  "host_id": "example-host",
  "boot_id": "Linux boot ID",
  "sequence": 42,
  "source": "lifecycle-wrapper"
}
```

`host_id`, `boot_id`, and `sequence` make events unambiguously orderable
when logs from multiple hosts and reboots are merged. `sequence` increases
for each event written during a boot.

Events extracted after the fact from generic-worker logs also contain:

```json
{
  "event_time": "2026-08-05T23:01:12.000Z",
  "recorded_at": "2026-08-05T23:03:14.123Z",
  "source": "generic-worker-log",
  "parser_version": 1,
  "source_record_id": "stable journal-record ID"
}
```

`event_time` is the original generic-worker log timestamp, while
`recorded_at` is when the importer wrote the lifecycle event. This
distinction prevents delayed parsing from looking like delayed worker
readiness or task start.

## Initial Events

The initial Linux event set is intentionally small:

| Event | Source | Meaning |
| --- | --- | --- |
| `worker_started` | Explicit wrapper hook | The wrapper is about to invoke `start-worker`. |
| `worker_ready` | generic-worker log import | generic-worker reached the selected, documented ready marker. |
| `task_started` | generic-worker log import | generic-worker log evidence identifies a task run beginning. |
| `task_finished` | generic-worker log import | generic-worker log evidence identifies that task run completing. |
| `worker_exited` | Explicit wrapper hook | `start-worker` returned to the wrapper; includes its exit code. |
| `restart_executed` | Explicit wrapper hook | The wrapper has reached the point where it invokes the reboot command. |

Task events include `task_id` and a task run or attempt identifier when the
generic-worker record provides one.

`restart_executed` records that the reboot command was invoked; it does not
claim that reboot completed. A subsequent `worker_started` with a new
`boot_id` establishes that the host returned and began launching the worker.

The normal lifecycle is:

```text
worker_started -> worker_ready -> task_started -> task_finished
    -> worker_exited -> restart_executed -> worker_started (new boot_id)
```

The sequence is not a success criterion. Missing events are expected for
worker crashes, host failures, quarantine, operator holds, and collection
before a lifecycle has completed.

## Logger and Generic-Worker Importer

One small `lifecycle-log` tool provides two separate responsibilities:

```text
lifecycle-log emit worker_started
lifecycle-log emit worker_exited --exit-code 0
lifecycle-log emit restart_executed --trigger post_task
lifecycle-log import-generic-worker --journal-tag generic-worker
```

`emit` is deliberately simple: it writes a fact at the current time and
automatically supplies the host, current Linux `boot_id`, and sequence.

`import-generic-worker` reads the generic-worker records from journald,
recognizes the supported log markers, preserves their original timestamps,
and appends extracted lifecycle events. It is generic-worker-version-aware
and records its parser version.

The importer is idempotent. Each imported source record receives a stable
`source_record_id`; the importer checks the current JSONL log and does not
write an event already represented by that ID. The ID remains in the event
so offline analysis can also deduplicate records.

## Initial Analysis

Only compute a duration when both named endpoints are present and have the
expected host, boot, and task/run relationship:

| Measurement | Calculation | Meaning |
| --- | --- | --- |
| Task runtime | `task_finished - task_started` | Time executing a task. |
| Post-task overhead | `restart_executed - task_finished` | Wrapper work after task completion and before reboot invocation. |
| Restart-to-worker | next `worker_started` - `restart_executed` | End-to-end time for host restart and pre-worker initialization. |
| Worker initialization | `worker_ready - worker_started` | Time from launching `start-worker` until generic-worker is ready. |
| Idle/claim latency | `task_started - worker_ready` | Time a ready worker waits before starting a task. |

If an endpoint is missing, the duration is unavailable rather than inferred.
Analysis may classify an incomplete lifecycle only after a defined threshold
and relative to the collection time. For example, a
`restart_executed` event without a new-boot `worker_started` after a chosen
threshold is a possible failed return, not proof of one.

## Deferred Events and Enhancements

Do not add an event until it has a concrete Linux hook and a specific
measurement purpose. Candidates include:

- `shutdown_started`, from a best-effort systemd shutdown hook, if splitting
  reboot-command delay from the remainder of the restart cycle becomes useful.
- `cleanup_started` and `cleanup_finished`, once the exact cleanup operation
  to measure is defined.
- Centralized ingestion, dashboards, and alerting after the event model and
  analysis are validated locally.

## Decisions Still Needed Before Implementation

- Confirm journald retention and the exact generic-worker markers for the
  deployed version.
- Choose the canonical Linux `host_id` and JSONL path, permissions, rotation,
  retention, and append/locking behavior.
- Define the importer source-record identity and collection/analysis
  thresholds.
- Select pilot hosts and the expected event coverage and first report.
