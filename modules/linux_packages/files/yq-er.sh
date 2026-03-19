#!/usr/bin/env bash
set -euo pipefail

# yq-er: extract raw value from YAML file at given path
# usage: yq-er <.path.to.key> <file.yaml>

# why: yq isn't available on older systems like Ubuntu 18.04,
# and we only need a small subset of its functionality. This script
# provides a minimal replacement for the -r (raw output) and -e
# (error if missing/null) flags of yq.

if [[ $# -ne 2 ]]; then
  echo "usage: yq-er <.path.to.key> <file.yaml>" >&2
  exit 2
fi

path="$1"
file="$2"

python3 - "$path" "$file" <<'PY'
import sys
import yaml

path = sys.argv[1]
filename = sys.argv[2]

if not path.startswith("."):
    print("path must start with '.'", file=sys.stderr)
    sys.exit(2)

keys = path.lstrip(".").split(".")

try:
    with open(filename) as f:
        data = yaml.safe_load(f)

    cur = data
    for k in keys:
        if isinstance(cur, list):
            cur = cur[int(k)]
        else:
            cur = cur[k]

    if cur in (None, ""):
        raise KeyError("null/empty value")

    # raw output, like -r
    print(cur)

except Exception as e:
    print(f"error: {path} not found or null", file=sys.stderr)
    sys.exit(1)
PY
