# collect_moonshot_hang_reports.py — deferred review items

Issues not addressed in the first pass. Review after initial fixes are tested.

---

## Medium priority — ~~fixed in second pass~~

### ~~M1. SIGINT during `check=True` subprocess bypasses friendly shutdown~~ ✓ fixed
Per-host loop body wrapped in `try/except Exception`; unexpected errors route to `fail_hosts` and are logged rather than propagating as tracebacks.

### ~~M2. `--freshness-requirement 0` is still nonsensical~~ ✓ fixed
Added `>= 1` validation parallel to `--loop-interval`.

### ~~M3. `reset_moonshot.py` receives user-form hostnames, not FQDNs~~ ✓ fixed (also fixes M5)
All three host resolution paths (auto, argv, stdin) now normalise to FQDNs via `worker_fqdn()` immediately. State keys, the reset call, and downstream code all receive canonical FQDNs.

### ~~M4. SIGINT handler placement — no-op~~ ✓ closed
Placement is correct and intentional. No code change needed.

---

## Low priority — ~~fixed or closed in third pass~~

### ~~L1. Voice-hours help string is off by one~~ ✓ fixed
Help string updated to `{VOICE_HOUR_START}:00–before {VOICE_HOUR_END}:00` to reflect the half-open interval.

### ~~L2. `fmt()` strips timezone then re-stamps `Z`~~ ✓ fixed
Changed to `s[:19].replace("T", " ") + " UTC"` — includes seconds and uses an unambiguous suffix.

### ~~L3. `recently_processed` rglob too broad~~ ✓ fixed
Pattern tightened to `????????T??????Z-{label}.md` to match only script-generated filenames.

### ~~L4. Module docstring `HOST ...` indentation~~ ✓ fixed
Indentation aligned with the other flag lines.

### ~~L5. Docstring hardcodes "60 minutes"~~ ✓ fixed
Updated to reference `RECENCY_MINUTES` by name so it stays in sync if the constant changes.

### ~~L6. `last_failed` retains old value across empty iterations~~ ✓ fixed
`last_failed = False` reset at the top of each `while True` iteration.

### ~~L7. `_emit` ANSI / `_use_color` set once at startup~~ ✓ closed (no-op)
Fixing this requires restructuring all color output. Not worth it; known limitation.

### ~~L8. `total_resets` semantics~~ ✓ closed (informational)
Column is accurate after the first-pass fix. Old state files may have inflated values — no action needed.
