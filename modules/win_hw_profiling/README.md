# win_hw_profiling

xperf-based hardware profiling for Windows CI workers.

This module provides two independent xperf trace mechanisms:

| Class | Trace options | Changed by |
|-------|---------------|-----------|
| `win_hw_profiling::xperf_kernel_trace` | **fixed** (hardcoded in `xperf_kernel_start.ps1`) | editing the script + Puppet run |
| `win_hw_profiling::xperf_dynamic_trace` | **dynamic** (run-time options file) | editing a JSON file on the worker; no Puppet run |

The two are fully independent — `xperf_dynamic_trace` was added without
modifying the existing `xperf_kernel_trace` scripts or tasks (RELOPS-2467).

## `xperf_dynamic_trace`

### What Puppet does

Puppet **only stages the pieces**. It drops three scripts and registers two
SYSTEM scheduled tasks:

- `xperf_dyn_trace_start`
- `xperf_dyn_trace_stop`

Both run as `SYSTEM` at highest run level, with a `BUILTIN\Users` GR/GX ACE so
an unprivileged task user can **trigger** them (read + execute) but not modify
them. Puppet never runs the trace itself, and tasks are only re-registered when
a script changes — never when trace options change.

### What a task does at run time

1. Write an options file into the task user's own profile:

   ```
   C:\Users\<interactive-user>\xperf\xperf_dyn_options.json
   ```

2. Trigger the start task, e.g.:

   ```
   schtasks /run /tn xperf_dyn_trace_start
   ```

3. Run the workload.

4. Trigger the stop task:

   ```
   schtasks /run /tn xperf_dyn_trace_stop
   ```

5. Collect the merged trace (`combined.etl` by default) from the same
   `...\xperf\` directory as a task artifact.

If no options file is present (or it fails validation) the start/stop scripts
fall back to built-in defaults that match `xperf_kernel_trace`.

### Options file schema

All fields are optional; anything missing or invalid falls back to defaults.

```json
{
  "sessions": [
    {
      "name": "NT Kernel Logger",
      "on": "PROC_THREAD+LOADER+PROFILE+CSWITCH",
      "stackwalk": "PROFILE+CSWITCH",
      "buffersize": 1024,
      "file": "kernel_session.etl"
    },
    {
      "name": "usersession",
      "on": "Microsoft-Windows-Kernel-Processor-Power:0x80+Microsoft-JScript:0x3",
      "buffersize": 1024,
      "file": "user_session.etl"
    }
  ],
  "output": "combined.etl"
}
```

| Field | Rule |
|-------|------|
| `sessions[].name` | 1–64 chars, `[A-Za-z0-9 ._-]` (spaces allowed) |
| `sessions[].on` | 1–4096 chars, `[A-Za-z0-9+:._-]` (no spaces/metacharacters) |
| `sessions[].stackwalk` | optional; same charset as `on` |
| `sessions[].buffersize` | integer 64–65536 |
| `sessions[].file` | bare `*.etl` filename, `[A-Za-z0-9._-]` (no path separators/traversal) |
| `output` | bare `*.etl` filename for the merged trace (default `combined.etl`) |

**Trace scope is intentionally not restricted** — developers may request any
providers/kernel flags they need.

### Security / containment

The options file is written by an unprivileged user and consumed by a SYSTEM
task, so the start/stop scripts enforce process containment:

- The **only** executable ever launched is script-resolved `xperf.exe`. The
  options file cannot name a program or a path to one.
- **The script owns the flags; the file owns only the values.** Validated
  values fill the `-start/-on/-stackwalk/-f/-BufferSize` slots — the file
  cannot introduce a new flag or an extra argv token.
- xperf is invoked as `& $xperf @args` (argument array, **no shell**), so
  metacharacters in a value are inert.
- Every value is validated (charset / integer bounds / bare filename). Any
  failure falls back to defaults; the scripts never fail open.
