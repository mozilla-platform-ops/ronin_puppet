#!/usr/bin/env bash

set -u -o pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <kitchen-target>" >&2
  exit 64
fi

target=$1
max_attempts=${KITCHEN_LINUX_MAX_ATTEMPTS:-3}
retry_delay=${KITCHEN_LINUX_RETRY_DELAY_SECONDS:-60}
temporary_directory=${RUNNER_TEMP:-${TMPDIR:-/tmp}}

if [[ ! $max_attempts =~ ^[1-9][0-9]*$ ]]; then
  echo "KITCHEN_LINUX_MAX_ATTEMPTS must be a positive integer." >&2
  exit 64
fi

if [[ ! $retry_delay =~ ^[0-9]+$ ]]; then
  echo "KITCHEN_LINUX_RETRY_DELAY_SECONDS must be a non-negative integer." >&2
  exit 64
fi

attempt_log=$(mktemp "${temporary_directory%/}/kitchen-linux-converge.XXXXXX")
trap 'rm -f "$attempt_log"' EXIT

is_temporary_apt_failure() {
  grep -Eiq \
    'Hash Sum mismatch|Temporary failure resolving|Could not connect to|Unable to connect to|Connection (timed out|failed|reset)' \
    "$1"
}

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  echo "Kitchen converge attempt $attempt of $max_attempts for $target."

  bundle exec kitchen converge "$target" 2>&1 | tee "$attempt_log"
  command_statuses=("${PIPESTATUS[@]}")
  kitchen_status=${command_statuses[0]}
  tee_status=${command_statuses[1]}

  if ((tee_status != 0)); then
    echo "tee failed with exit code $tee_status." >&2
    exit "$tee_status"
  fi

  if ((kitchen_status == 0)); then
    exit 0
  fi

  if ! is_temporary_apt_failure "$attempt_log"; then
    echo "Kitchen failed without a recognized temporary APT error. The command will not run again." >&2
    exit "$kitchen_status"
  fi

  if ((attempt == max_attempts)); then
    echo "Kitchen failed after $max_attempts attempts." >&2
    exit "$kitchen_status"
  fi

  echo "Kitchen failed because of a temporary APT error. The command will run again in $retry_delay seconds." >&2
  sleep "$retry_delay"
done
