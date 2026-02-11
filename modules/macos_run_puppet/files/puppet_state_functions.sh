#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Puppet State Functions Library
#
# This file contains shell functions for writing puppet run metadata.
# It should be sourced by run-puppet.sh, not executed directly.
#
# Installation:
#   Install this file at: /etc/puppet/lib/puppet_state_functions.sh
#
# Usage in run-puppet.sh:
#   source /etc/puppet/lib/puppet_state_functions.sh
#
#   SECONDS=0
#   run_puppet
#   retval=$?
#   PUPPET_RUN_DURATION=$SECONDS
#   write_puppet_state "$WORKING_DIR" "$ROLE" "$retval" "$PUPPET_RUN_DURATION" \
#       "/etc/puppet/ronin_settings" "/root/vault.yaml"
#
# Testing:
#   write_puppet_state "$WORKING_DIR" "$ROLE" "$retval" "$PUPPET_RUN_DURATION" \
#       "/etc/puppet/ronin_settings" "/root/vault.yaml" "/tmp/test_state.json"
#
# Functions provided:
#   write_puppet_state - Writes puppet run metadata to /etc/puppet/last_run_metadata.json
#
# CRITICAL: This function must NEVER fail the puppet run.
# All errors are logged but execution continues.

# write_puppet_state
# Writes puppet run metadata to /etc/puppet/last_run_metadata.json
# This provides ground truth about what puppet actually applied.
#
# Parameters:
#   working_dir    - Git working directory for puppet code (e.g., /etc/puppet/environments/mozilla-platform-ops/code)
#   role           - Puppet role that was applied (e.g., gecko-t-linux-talos)
#   exit_code      - Puppet exit code (0=no changes, 2=changes applied, other=failure)
#   duration_s     - How long the puppet run took in seconds
#   override_path  - Path to override file (e.g., /etc/puppet/ronin_settings or /opt/puppet_environments/ronin_settings)
#   vault_path     - Path to vault file (e.g., /root/vault.yaml or /var/root/vault.yaml)
#   state_file     - Optional output path (default: /etc/puppet/last_run_metadata.json)

# shellcheck disable=SC2317  # Catch-all error handler is intentionally unreachable
write_puppet_state() {
    # Wrap entire function to ensure it never fails puppet run
    {
        local working_dir="$1"
        local role="$2"
        local exit_code="$3"
        local duration_s="$4"
        local override_path="$5"
        local vault_path="$6"
        local state_file="${7:-/etc/puppet/last_run_metadata.json}"

        local temp_file="${state_file}.tmp"

        # Detect OS for SHA command
        local sha_cmd
        if command -v sha256sum >/dev/null 2>&1; then
            # Linux
            sha_cmd="sha256sum"
        elif command -v shasum >/dev/null 2>&1; then
            # macOS
            sha_cmd="shasum -a 256"
        else
            echo "ERROR: write_puppet_state: No SHA command found (sha256sum or shasum)" >&2
            return 0
        fi

        # Generate ISO 8601 timestamp
        local ts
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "null")

        # Determine success (exit codes 0 or 2 are success)
        local success
        if [[ "$exit_code" == "0" || "$exit_code" == "2" ]]; then
            success="true"
        else
            success="false"
        fi

        # Extract git info from working directory
        local git_repo="null"
        local git_branch="null"
        local git_sha="null"
        local git_dirty="null"

        if [[ -d "$working_dir/.git" ]]; then
            pushd "$working_dir" >/dev/null 2>&1 || true

            # Get repo URL
            local repo_url
            repo_url=$(git config --get remote.origin.url 2>/dev/null || true)
            if [[ -n "$repo_url" ]]; then
                git_repo="\"$repo_url\""
            fi

            # Get branch name
            local branch_name
            branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
            if [[ -n "$branch_name" ]]; then
                git_branch="\"$branch_name\""
            fi

            # Get commit SHA
            local commit_sha
            commit_sha=$(git rev-parse HEAD 2>/dev/null || true)
            if [[ -n "$commit_sha" ]]; then
                git_sha="\"$commit_sha\""
            fi

            # Check if repo is dirty (has uncommitted changes or untracked files)
            local status_output
            status_output=$(git status --porcelain 2>/dev/null || true)
            if [[ -n "$status_output" ]]; then
                git_dirty="true"
            else
                git_dirty="false"
            fi

            popd >/dev/null 2>&1 || true
        fi

        # Calculate override SHA
        local override_sha="null"
        if [[ -f "$override_path" ]]; then
            local override_hash
            override_hash=$($sha_cmd "$override_path" 2>/dev/null | awk '{print $1}')
            if [[ -n "$override_hash" ]]; then
                override_sha="\"$override_hash\""
            fi
        fi

        # Calculate vault SHA
        local vault_sha="null"
        if [[ -f "$vault_path" ]]; then
            local vault_hash
            vault_hash=$($sha_cmd "$vault_path" 2>/dev/null | awk '{print $1}')
            if [[ -n "$vault_hash" ]]; then
                vault_sha="\"$vault_hash\""
            fi
        fi

        # Escape paths for JSON (handle quotes and backslashes)
        local override_path_escaped
        override_path_escaped=$(printf '%s' "$override_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
        local vault_path_escaped
        vault_path_escaped=$(printf '%s' "$vault_path" | sed 's/\\/\\\\/g; s/"/\\"/g')

        # Build JSON (no trailing commas for maximum compatibility)
        local json
        json=$(cat <<EOF
{
  "schema_version": 1,
  "ts": "$ts",
  "duration_s": $duration_s,
  "success": $success,
  "exit_code": $exit_code,
  "role": "$role",
  "git_repo": $git_repo,
  "git_branch": $git_branch,
  "git_sha": $git_sha,
  "git_dirty": $git_dirty,
  "vault_path": "$vault_path_escaped",
  "vault_sha": $vault_sha,
  "override_path": "$override_path_escaped",
  "override_sha": $override_sha
}
EOF
        )

        # Write atomically: temp file then rename
        if echo "$json" > "$temp_file" 2>/dev/null; then
            # Set permissions before moving (world-readable for SSH access)
            chmod 0644 "$temp_file" 2>/dev/null || true

            # Atomic rename
            if mv "$temp_file" "$state_file" 2>/dev/null; then
                echo "Puppet state written to $state_file" >&2
            else
                echo "ERROR: write_puppet_state: Failed to rename temp file to $state_file" >&2
                rm -f "$temp_file" 2>/dev/null || true
            fi
        else
            echo "ERROR: write_puppet_state: Failed to write temp file $temp_file" >&2
            rm -f "$temp_file" 2>/dev/null || true
        fi

        # Always return success
        return 0

    } || {
        # Catch-all: even if something unexpected fails, return success
        echo "ERROR: write_puppet_state: Unexpected error occurred" >&2
        return 0
    }
}

# Export function for use in other scripts
export -f write_puppet_state 2>/dev/null || true
