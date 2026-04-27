#!/usr/bin/env bash
# Collect hang-diagnostic reports from hung/rebooted t-linux64-ms-* cartridges.
#
# Usage:
#   collect_moonshot_hang_reports.sh [--auto] [--no-reset] [--no-freshness] [--ignore-recency] [HOST ...]
#
#   --auto            Fetch bad-host list from fleetroll instead of reading argv/stdin.
#   --no-reset        Skip iLO reboot (host already freshly rebooted).
#   --no-freshness    Skip fleetroll data-freshness check when using --auto.
#   --ignore-recency  Process hosts even if collected within the last 60 minutes.
#   HOST ...          Short (ms025) or FQDN. If omitted and not --auto, reads stdin.

set -euo pipefail

FLEETROLL_DIR="$HOME/git/fleetroll_mvp"
RESET_DIR="$HOME/git/relops-infra/moonshot"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HANG_SCRIPT="$SCRIPT_DIR/moonshot_hang_report.py"
RESULTS_BASE="$REPO_DIR/moonshot_debugging_results"
FQDN_SUFFIX=".test.releng.mdc1.mozilla.com"

# --- colors (disabled when not a tty) ---
if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_BLUE='\033[1;34m'
    C_CYAN='\033[1;36m'
    C_GREEN='\033[1;32m'
    C_YELLOW='\033[1;33m'
    C_RED='\033[1;31m'
else
    C_RESET=''; C_BOLD=''; C_BLUE=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

info()    { echo -e "${C_BLUE}==>${C_RESET}${C_BOLD} $*${C_RESET}"; }
section() { echo -e "${C_CYAN}--- $* ---${C_RESET}"; }
ok()      { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
err()     { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; }

# --- parse args ---
AUTO=0
NO_RESET=0
NO_FRESHNESS=0
IGNORE_RECENCY=0
RECENCY_MINUTES=60
HOSTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)             AUTO=1 ;;
        --no-reset)         NO_RESET=1 ;;
        --no-freshness)     NO_FRESHNESS=1 ;;
        --ignore-recency)   IGNORE_RECENCY=1 ;;
        -h|--help)
            sed -n '2,10p' "$0" | sed 's/^# //'
            exit 0
            ;;
        -*)
            err "Unknown option: $1"
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
        err "Required directory not found: $dep_dir"
        exit 1
    fi
done
if [[ ! -f "$HANG_SCRIPT" ]]; then
    err "Diagnostic script not found: $HANG_SCRIPT"
    exit 1
fi

# --- helper: extract numeric slot from any ms hostname form ---
# Accepts: ms004, ms-004, t-linux64-ms-004, t-linux64-ms-004.fqdn.com
# Returns the zero-padded 3-digit slot number, e.g. "004"
_ms_slot() {
    local base="${1%%.*}"   # strip domain
    if [[ "$base" =~ ms-([0-9]+)$ ]]; then
        printf "%03d" "$((10#${BASH_REMATCH[1]}))"
    elif [[ "$base" =~ ms([0-9]+)$ ]]; then
        printf "%03d" "$((10#${BASH_REMATCH[1]}))"
    else
        echo ""
    fi
}

fqdn_of() {
    local h="$1"
    # already a FQDN
    if [[ "$h" == *.* ]]; then
        echo "$h"
        return
    fi
    local slot
    slot=$(_ms_slot "$h")
    if [[ -n "$slot" ]]; then
        printf "t-linux64-ms-%s%s" "$slot" "$FQDN_SUFFIX"
    else
        # not an ms host — just append suffix and hope for the best
        echo "${h}${FQDN_SUFFIX}"
    fi
}

short_label_of() {
    local slot
    slot=$(_ms_slot "$1")
    if [[ -n "$slot" ]]; then
        echo "ms${slot}"
    else
        echo "${1%%.*}"
    fi
}

recently_processed() {
    local label="$1"
    [[ -n "$(find "$RESULTS_BASE" -type f -name "*-${label}.md" -mmin -"$RECENCY_MINUTES" -print -quit 2>/dev/null)" ]]
}

# --- freshness gate ---
if [[ "$AUTO" -eq 1 && "$NO_FRESHNESS" -eq 0 ]]; then
    info "Checking fleetroll data freshness..."
    if ! (cd "$FLEETROLL_DIR" && uv run fleetroll data-freshness); then
        echo ""
        err "Fleetroll data is stale. Refresh it or pass --no-freshness to skip this check."
        exit 1
    fi
fi

# --- resolve host list ---
if [[ "$AUTO" -eq 1 ]]; then
    info "Fetching bad-host list from fleetroll..."
    raw_hosts=$(cd "$FLEETROLL_DIR" && bash tools/list_bad_linux_hosts.sh)
    # split on whitespace
    read -r -a HOSTS <<< "$raw_hosts"
elif [[ "${#HOSTS[@]}" -eq 0 ]]; then
    if [[ -t 0 ]]; then
        echo -e "${C_BOLD}Enter hostnames (one per line, Ctrl-D to finish):${C_RESET}" >&2
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] && HOSTS+=("$line")
    done
fi

if [[ "${#HOSTS[@]}" -eq 0 ]]; then
    warn "No hosts specified. Nothing to do."
    exit 0
fi

# --- recency filter ---
if [[ "$IGNORE_RECENCY" -eq 0 ]]; then
    FILTERED=()
    SKIPPED=()
    for h in "${HOSTS[@]}"; do
        if recently_processed "$(short_label_of "$h")"; then
            SKIPPED+=("$h")
        else
            FILTERED+=("$h")
        fi
    done
    if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
        warn "Skipping ${#SKIPPED[@]} host(s) processed within last ${RECENCY_MINUTES} min: ${SKIPPED[*]}"
        warn "(use --ignore-recency to override)"
    fi
    HOSTS=("${FILTERED[@]}")
    if [[ "${#HOSTS[@]}" -eq 0 ]]; then
        info "All requested hosts were recently processed. Nothing to do."
        exit 0
    fi
fi

info "Hosts to process: ${HOSTS[*]}"

# --- create results dir ---
RUN_DIR="$RESULTS_BASE/$(date -u +"%Y%m%d")"
mkdir -p "$RUN_DIR"
LOG="$RUN_DIR/run.log"
info "Results will be saved to: $RUN_DIR"
info "Log: $LOG"

# tee all subsequent output to log
exec > >(tee -a "$LOG") 2>&1

echo "Run started at $(date -u)"
echo "Hosts: ${HOSTS[*]}"
echo ""

# --- reset ---
if [[ "$NO_RESET" -eq 0 ]]; then
    info "Resetting hosts via iLO (waiting for them to come back online)..."
    (cd "$RESET_DIR" && uv run ./reset_moonshot.py --force "${HOSTS[@]}")
    echo ""
else
    warn "Skipping reset (--no-reset)."
fi

# --- collect reports ---
OK_HOSTS=()
FAIL_HOSTS=()

for host in "${HOSTS[@]}"; do
    fqdn=$(fqdn_of "$host")
    label=$(short_label_of "$host")
    collect_ts=$(date -u +"%Y%m%dT%H%M%SZ")
    out_file="$RUN_DIR/${collect_ts}-${label}.md"

    section "$label  $fqdn"

    host_ok=1

    scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
        "$HANG_SCRIPT" "${fqdn}:/tmp/moonshot_hang_report.py" \
        || { err "[$label] scp upload failed"; host_ok=0; }

    if [[ "$host_ok" -eq 1 ]]; then
        ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
            "$fqdn" "sudo python3 /tmp/moonshot_hang_report.py -o /tmp/hang_report.md" \
            || { err "[$label] remote script failed"; host_ok=0; }
    fi

    if [[ "$host_ok" -eq 1 ]]; then
        scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
            "${fqdn}:/tmp/hang_report.md" "$out_file" \
            || { err "[$label] scp download failed"; host_ok=0; }
    fi

    # cleanup regardless of prior failures
    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 \
        "$fqdn" "rm -f /tmp/moonshot_hang_report.py /tmp/hang_report.md" 2>/dev/null || true

    if [[ "$host_ok" -eq 1 ]]; then
        ok "[$label] -> $out_file"
        OK_HOSTS+=("$label")
        section "$label  host-audit"
        audit_file="$RUN_DIR/${collect_ts}-${label}-audit.txt"
        if (cd "$FLEETROLL_DIR" && uv run fleetroll host-audit "$fqdn" > "$audit_file" 2>&1); then
            ok "[$label] audit -> $audit_file"
        else
            warn "[$label] host-audit failed (see $audit_file)"
        fi
    else
        err "[$label] collection failed"
        FAIL_HOSTS+=("$label")
    fi
    echo ""
done

# --- summary ---
echo -e "${C_BOLD}========================================${C_RESET}"
echo -e "${C_BOLD}Run complete:${C_RESET} $RUN_DIR"
if [[ "${#OK_HOSTS[@]}" -gt 0 ]]; then
    echo -e "${C_GREEN}OK:  ${C_RESET} ${OK_HOSTS[*]}"
fi
if [[ "${#FAIL_HOSTS[@]}" -gt 0 ]]; then
    echo -e "${C_RED}FAIL:${C_RESET} ${FAIL_HOSTS[*]}"
fi
echo -e "${C_BOLD}========================================${C_RESET}"

if [[ "${#FAIL_HOSTS[@]}" -gt 0 ]]; then
    exit 1
fi
