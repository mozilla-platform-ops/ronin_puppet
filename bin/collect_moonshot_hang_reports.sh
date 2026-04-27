#!/usr/bin/env bash
# Collect hang-diagnostic reports from hung/rebooted t-linux64-ms-* cartridges.
#
# Usage:
#   collect_moonshot_hang_reports.sh [--auto] [--no-reset] [--no-freshness] [HOST ...]
#
#   --auto          Fetch bad-host list from fleetroll instead of reading argv/stdin.
#   --no-reset      Skip iLO reboot (host already freshly rebooted).
#   --no-freshness  Skip fleetroll data-freshness check when using --auto.
#   HOST ...        Short (ms025) or FQDN. If omitted and not --auto, reads stdin.

set -euo pipefail

FLEETROLL_DIR="$HOME/git/fleetroll_mvp"
RESET_DIR="$HOME/git/relops-infra/moonshot"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HANG_SCRIPT="$REPO_DIR/moonshot_hang_report.py"
RESULTS_BASE="$REPO_DIR/moonshot_debugging_results"
FQDN_SUFFIX=".test.releng.mdc1.mozilla.com"

# --- parse args ---
AUTO=0
NO_RESET=0
NO_FRESHNESS=0
HOSTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)           AUTO=1 ;;
        --no-reset)       NO_RESET=1 ;;
        --no-freshness)   NO_FRESHNESS=1 ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# //'
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            HOSTS+=("$1")
            ;;
    esac
    shift
done

# --- verify dependencies ---
for dep_dir in "$FLEETROLL_DIR" "$RESET_DIR"; do
    if [[ ! -d "$dep_dir" ]]; then
        echo "ERROR: required directory not found: $dep_dir" >&2
        exit 1
    fi
done
if [[ ! -f "$HANG_SCRIPT" ]]; then
    echo "ERROR: diagnostic script not found: $HANG_SCRIPT" >&2
    exit 1
fi

# --- helper: normalize hostname to FQDN and short label ---
fqdn_of() {
    local h="$1"
    if [[ "$h" == *.* ]]; then
        echo "$h"
    else
        # e.g. ms025 → t-linux64-ms-025
        local digits="${h#ms}"
        printf "t-linux64-ms-%03d%s" "$((10#$digits))" "$FQDN_SUFFIX"
    fi
}

short_label_of() {
    local h="$1"
    # t-linux64-ms-025.xxx → ms025; ms025 → ms025
    local base="${h%%.*}"
    if [[ "$base" =~ ms-([0-9]+)$ ]]; then
        printf "ms%03d" "$((10#${BASH_REMATCH[1]}))"
    else
        echo "$base"
    fi
}

# --- freshness gate ---
if [[ "$AUTO" -eq 1 && "$NO_FRESHNESS" -eq 0 ]]; then
    echo "==> Checking fleetroll data freshness..."
    if ! (cd "$FLEETROLL_DIR" && uv run fleetroll data-freshness); then
        echo ""
        echo "ERROR: fleetroll data is stale. Refresh it or pass --no-freshness to skip this check." >&2
        exit 1
    fi
fi

# --- resolve host list ---
if [[ "$AUTO" -eq 1 ]]; then
    echo "==> Fetching bad-host list from fleetroll..."
    raw_hosts=$(cd "$FLEETROLL_DIR" && bash tools/list_bad_linux_hosts.sh)
    # split on whitespace
    read -r -a HOSTS <<< "$raw_hosts"
elif [[ "${#HOSTS[@]}" -eq 0 ]]; then
    if [[ -t 0 ]]; then
        echo "Enter hostnames (one per line, Ctrl-D to finish):" >&2
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] && HOSTS+=("$line")
    done
fi

if [[ "${#HOSTS[@]}" -eq 0 ]]; then
    echo "No hosts specified. Nothing to do."
    exit 0
fi

echo "==> Hosts to process: ${HOSTS[*]}"

# --- create results dir ---
RUN_TS=$(date -u +"%Y%m%dT%H%M%SZ")
RUN_DIR="$RESULTS_BASE/$RUN_TS"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/run.log"
echo "==> Results will be saved to: $RUN_DIR"
echo "==> Log: $LOG"

# tee all subsequent output to log
exec > >(tee -a "$LOG") 2>&1

echo "Run started at $(date -u)"
echo "Hosts: ${HOSTS[*]}"
echo ""

# --- reset ---
if [[ "$NO_RESET" -eq 0 ]]; then
    echo "==> Resetting hosts via iLO (waiting for them to come back online)..."
    (cd "$RESET_DIR" && uv run ./reset_moonshot.py --force "${HOSTS[@]}")
    echo ""
else
    echo "==> Skipping reset (--no-reset)."
fi

# --- collect reports ---
OK_HOSTS=()
FAIL_HOSTS=()

for host in "${HOSTS[@]}"; do
    fqdn=$(fqdn_of "$host")
    label=$(short_label_of "$host")
    collect_ts=$(date -u +"%Y%m%dT%H%M%SZ")
    out_file="$RUN_DIR/${collect_ts}-${label}.md"

    echo "--- [$label] Collecting report from $fqdn ---"

    host_ok=1

    scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
        "$HANG_SCRIPT" "${fqdn}:/tmp/moonshot_hang_report.py" \
        || { echo "[$label] ERROR: scp upload failed"; host_ok=0; }

    if [[ "$host_ok" -eq 1 ]]; then
        ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
            "$fqdn" "sudo python3 /tmp/moonshot_hang_report.py -o /tmp/hang_report.md" \
            || { echo "[$label] ERROR: remote script failed"; host_ok=0; }
    fi

    if [[ "$host_ok" -eq 1 ]]; then
        scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
            "${fqdn}:/tmp/hang_report.md" "$out_file" \
            || { echo "[$label] ERROR: scp download failed"; host_ok=0; }
    fi

    # cleanup regardless of prior failures
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
        "$fqdn" "rm -f /tmp/moonshot_hang_report.py /tmp/hang_report.md" 2>/dev/null || true

    if [[ "$host_ok" -eq 1 ]]; then
        echo "[$label] OK -> $out_file"
        OK_HOSTS+=("$label")
    else
        FAIL_HOSTS+=("$label")
    fi
    echo ""
done

# --- summary ---
echo "========================================"
echo "Run complete: $RUN_DIR"
if [[ "${#OK_HOSTS[@]}" -gt 0 ]]; then
    echo "OK:   ${OK_HOSTS[*]}"
fi
if [[ "${#FAIL_HOSTS[@]}" -gt 0 ]]; then
    echo "FAIL: ${FAIL_HOSTS[*]}"
fi
echo "========================================"

if [[ "${#FAIL_HOSTS[@]}" -gt 0 ]]; then
    exit 1
fi
