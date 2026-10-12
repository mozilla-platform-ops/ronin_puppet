#!/usr/bin/env bash

set -eu -o pipefail

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/test-kitchen-linux-converge.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT

mkdir -p "$test_directory/bin"

cat > "$test_directory/bin/bundle" <<'FAKE_BUNDLE'
#!/usr/bin/env bash

set -eu

if [[ $* != "exec kitchen converge test-target" ]]; then
  echo "Unexpected arguments: $*" >&2
  exit 65
fi

attempt=$(($(< "$FAKE_ATTEMPT_FILE") + 1))
printf '%s\n' "$attempt" > "$FAKE_ATTEMPT_FILE"

case "$FAKE_SCENARIO" in
  temporary_then_success)
    if ((attempt == 1)); then
      echo "E: Failed to fetch Packages.gz  Hash Sum mismatch"
      exit 20
    fi
    ;;
  permanent)
    echo "Error: Puppet could not compile the catalog."
    exit 42
    ;;
  temporary)
    echo "Temporary failure resolving an APT repository."
    exit 20
    ;;
  *)
    echo "Unknown test scenario: $FAKE_SCENARIO" >&2
    exit 65
    ;;
esac
FAKE_BUNDLE
chmod +x "$test_directory/bin/bundle"

run_case() {
  local scenario=$1
  local expected_status=$2
  local expected_attempts=$3
  local attempt_file="$test_directory/${scenario}.attempts"
  local status

  printf '0\n' > "$attempt_file"

  set +e
  PATH="$test_directory/bin:$PATH" \
    FAKE_ATTEMPT_FILE="$attempt_file" \
    FAKE_SCENARIO="$scenario" \
    KITCHEN_LINUX_MAX_ATTEMPTS=3 \
    KITCHEN_LINUX_RETRY_DELAY_SECONDS=0 \
    "$script_directory/kitchen_linux_converge.sh" test-target >/dev/null 2>&1
  status=$?
  set -e

  if [[ $status -ne $expected_status ]]; then
    echo "$scenario returned $status; expected $expected_status." >&2
    return 1
  fi

  if [[ $(< "$attempt_file") -ne $expected_attempts ]]; then
    echo "$scenario used $(< "$attempt_file") attempts; expected $expected_attempts." >&2
    return 1
  fi
}

run_case temporary_then_success 0 2
run_case permanent 42 1
run_case temporary 20 3

echo "Kitchen Linux converge retry tests passed."
