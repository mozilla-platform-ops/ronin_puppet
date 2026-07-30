# Dynamic xperf trace — usage

How to run an xperf trace with your own options on a Windows CI worker, using
the `win_hw_profiling::xperf_dynamic_trace` mechanism.

You pick what to trace by dropping a small JSON file in a known location, then
triggering two pre-registered scheduled tasks (start / stop). No admin rights,
no Puppet run, no editing scripts.

---

## File structure

Puppet stages these (you do **not** create or edit them):

| Path | What it is |
|------|-----------|
| `%custom_win_roninprogramdata%\xperf_dyn_start.ps1` | start script (runs as SYSTEM) |
| `%custom_win_roninprogramdata%\xperf_dyn_stop.ps1` | stop script (runs as SYSTEM) |
| `%custom_win_roninprogramdata%\xperf_dyn_register_tasks.ps1` | registers the two tasks (Puppet only) |
| Scheduled task `xperf_dyn_trace_start` | triggers the start script as SYSTEM |
| Scheduled task `xperf_dyn_trace_stop` | triggers the stop script as SYSTEM |

You provide / consume these at run time, in the **task user's own profile**:

| Path | What it is |
|------|-----------|
| `C:\Users\<you>\xperf\xperf_dyn_options.json` | **the options file you write** |
| `C:\Users\<you>\xperf\kernel_session.etl` | live kernel session (while running) |
| `C:\Users\<you>\xperf\user_session.etl` | live user session (while running) |
| `C:\Users\<you>\xperf\combined.etl` | **merged trace, produced on stop** |
| `C:\Users\<you>\xperf\xperf_dyn_start.log` / `xperf_dyn_stop.log` | run logs |

`<you>` is the interactive user the task runs under (your task user). The
scripts resolve this directory automatically; you don't hardcode a username.
The `xperf` directory is created for you if it doesn't exist.

---

## Where the options file goes

```
C:\Users\<you>\xperf\xperf_dyn_options.json
```

- If the file is **missing**, the trace runs with built-in defaults (matching
  the fixed `xperf_kernel_trace`).
- If the file is **present but invalid**, it is rejected and defaults are used
  (check `xperf_dyn_start.log` for a WARN line).
- Write the file **before** triggering the start task.

### Options schema

```json
{
  "sessions": [
    {
      "name": "NT Kernel Logger",
      "on": "PROC_THREAD+LOADER+PROFILE+CSWITCH",
      "stackwalk": "PROFILE+CSWITCH",
      "buffersize": 1024,
      "file": "kernel_session.etl"
    }
  ],
  "output": "combined.etl"
}
```

| Field | Required | Rule |
|-------|----------|------|
| `sessions[].name` | yes | 1–64 chars, `[A-Za-z0-9 ._-]` (spaces allowed, e.g. `NT Kernel Logger`) |
| `sessions[].on` | yes | 1–4096 chars, `[A-Za-z0-9+:._-]` (no spaces / shell metacharacters) |
| `sessions[].stackwalk` | no | same charset as `on`; omit the key for no `-stackwalk` |
| `sessions[].buffersize` | yes | integer, 64–65536 |
| `sessions[].file` | yes | bare `*.etl` filename, `[A-Za-z0-9._-]`, no path separators |
| `output` | no | bare `*.etl` filename for the merged trace (default `combined.etl`) |

You can list more than one session (e.g. a kernel session and a user session);
each becomes its own `-start ...` block. Trace scope is not restricted — request
whatever providers you need.

---

## How to start a trace

1. Write your options file:

   ```powershell
   $dir = Join-Path $env:USERPROFILE 'xperf'
   New-Item -ItemType Directory -Path $dir -Force | Out-Null

   @'
   {
     "sessions": [
       { "name": "NT Kernel Logger",
         "on": "PROC_THREAD+LOADER+PROFILE+CSWITCH",
         "stackwalk": "PROFILE+CSWITCH",
         "buffersize": 1024,
         "file": "kernel_session.etl" }
     ]
   }
   '@ | Set-Content -Path (Join-Path $dir 'xperf_dyn_options.json') -Encoding UTF8
   ```

2. Trigger the start task:

   ```
   schtasks /run /tn xperf_dyn_trace_start
   ```

3. Run your workload.

## How to stop a trace

```
schtasks /run /tn xperf_dyn_trace_stop
```

This stops every session named in your options file and merges them into the
`output` file (default `C:\Users\<you>\xperf\combined.etl`). Collect that `.etl`
as your task artifact.

> If you omit `output`, you get `combined.etl` next to the live
> `kernel_session.etl` / `user_session.etl`. Set `output` if you want a specific
> name.

---

## Examples

**CPU sampling + context switches (with stackwalk):**
```json
{ "sessions": [
  { "name": "NT Kernel Logger",
    "on": "PROC_THREAD+LOADER+PROFILE+CSWITCH",
    "stackwalk": "PROFILE+CSWITCH",
    "buffersize": 1024, "file": "kernel_session.etl" } ] }
```

**CPU sampling only:**
```json
{ "sessions": [
  { "name": "NT Kernel Logger",
    "on": "PROC_THREAD+LOADER+PROFILE",
    "stackwalk": "PROFILE",
    "buffersize": 1024, "file": "kernel_session.etl" } ] }
```

**File I/O (no stackwalk):**
```json
{ "sessions": [
  { "name": "NT Kernel Logger",
    "on": "PROC_THREAD+LOADER+FILE_IO+FILE_IO_INIT",
    "buffersize": 1024, "file": "kernel_session.etl" } ] }
```

---

## Notes / troubleshooting

- **Nothing traced / defaults used?** Check `xperf_dyn_start.log` in your
  `xperf` dir for a `WARN` about the options file failing validation.
- **Write, then trigger.** The SYSTEM task reads the file at trigger time; make
  sure the write has completed first.
- **Start and stop must run as the same user** so they resolve the same `xperf`
  directory — normal within a single task.
- The tasks always run `xperf.exe` and nothing else; the options file can only
  change xperf's arguments, never what program runs (see `README.md` for the
  security model).
