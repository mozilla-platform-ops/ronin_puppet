#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Reclaim two OS-owned caches that grow without bound on long-lived macOS
# workers. Invoked as root from worker-runner.sh between tasks.
#
#   /private/var/db/oah                       Rosetta 2 AOT translation cache
#   .../Caches/com.apple.coresymbolicationd   CoreSymbolication data
#
# Neither is tracked by generic-worker, so cleanUpTaskDirs and the file-cache
# purge in worker-runner.sh never touch them. When they push free space under
# generic-worker's requiredDiskSpaceMegabytes floor the worker refuses to claim:
#
#   "Not able to free up enough disk space - require 21474836480 bytes, but only
#    have 20450148352 bytes - and nothing left to delete"  ->  exit 69
#
# worker-runner then reboots and the host loops on that every ~84s, taking no
# work, with tasks-resolved-count.txt still 0. Because `tart run` on the VM host
# stays up throughout, the host looks healthy the whole time.
#
# Observed on gecko-t-osx-1500-m-vms (2026-08-13): 12 of 26 slots were out of
# production this way, having accumulated 12-29 GB in oah and, on mac-8744d8,
# 31 GB in coresymbolicationd. Purging both took mac-9972e2 from 19 GiB free to
# 41 GiB and it claimed a task within three minutes. Purging oah alone left
# mac-8744d8 still under the floor -- both have to go.
#
# WHY THIS IS THRESHOLD-GATED, unlike the file-cache purge in worker-runner.sh:
# clearing oah is not free. Rosetta must re-translate every x86_64 binary it had
# cached, and the next task to use one pays for it. So this only acts when the
# volume is near the floor, which makes it a no-op on hosts with headroom and
# self-correcting on the ones without. Do not make it unconditional.
#
# Staging: each cache is renamed aside and deleted detached, so worker startup
# never waits on 20-30 GB of unlink. A rename is O(1) however much has piled up,
# which matters for the first pass on an already-full host. Anything a previous
# run staged but did not finish deleting -- a reboot can cut the detached delete
# short -- is swept on the next run.
#
# oah is flagged `restricted`. The flag is cleared on the directory and its
# immediate children only, because a recursive walk here would block startup; the
# recursive pass happens inside the detached delete where nothing is waiting. On
# a SIP-enabled host clearing the flag fails, nothing moves, and the oah half is
# skipped -- the coresymbolicationd half is unaffected.

set -u
export PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin

OAH_DIR=/private/var/db/oah
CSYM_DIR=/System/Volumes/Data/System/Library/Caches/com.apple.coresymbolicationd
DEFAULT_FLOOR_GB=30

# The single argument is a free-space floor in whole GB. It is validated rather
# than trusted: this script is reachable through a NOPASSWD sudoers rule from the
# task user, so it must never act on caller-supplied input beyond one integer.
# Both cache paths are fixed above and are not overridable for the same reason.
floor_gb=$DEFAULT_FLOOR_GB
if [ "$#" -ge 1 ] && printf '%s' "$1" | grep -qE '^[0-9]+$'; then
    floor_gb=$1
fi

# Sweep leftovers from an interrupted previous run first, so a host that keeps
# getting cut short still converges instead of stacking up staged copies.
for stale in "${OAH_DIR}".purging.* "${CSYM_DIR}".purging.*; do
    [ -e "$stale" ] || continue
    echo "reclaim: sweeping stale staged cache ${stale}"
    ( chflags -R norestricted "$stale" >/dev/null 2>&1
      rm -rf "$stale" >/dev/null 2>&1 & )
done

avail_gb=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
if ! printf '%s' "$avail_gb" | grep -qE '^[0-9]+$'; then
    echo "reclaim: could not read free space on /; skipping"
    exit 0
fi

if [ "$avail_gb" -ge "$floor_gb" ]; then
    echo "reclaim: ${avail_gb}G free on / is at or above ${floor_gb}G; nothing to do"
    exit 0
fi

echo "reclaim: ${avail_gb}G free on / is below ${floor_gb}G; reclaiming OS caches"

# Rosetta 2 AOT cache. The directory itself and Oah.version are kept -- oahd
# recreates the per-binary trees on demand, but the version file is its own
# bookkeeping rather than cache payload.
if [ -d "$OAH_DIR" ]; then
    oah_stage="${OAH_DIR}.purging.$$"
    if mkdir -p "$oah_stage" 2>/dev/null; then
        chflags norestricted "$OAH_DIR" >/dev/null 2>&1 || true
        oah_moved=0
        for child in "$OAH_DIR"/*; do
            [ -e "$child" ] || continue
            if [ "${child##*/}" = "Oah.version" ]; then
                continue
            fi
            chflags norestricted "$child" >/dev/null 2>&1 || true
            if mv "$child" "$oah_stage"/ >/dev/null 2>&1; then
                oah_moved=$((oah_moved + 1))
            fi
        done
        if [ "$oah_moved" -eq 0 ]; then
            # Nothing moved: either already empty or the flags could not be
            # cleared (SIP enabled). Leave no empty staging directory behind.
            rmdir "$oah_stage" >/dev/null 2>&1 || true
        else
            echo "reclaim: staged ${oah_moved} Rosetta cache entry/entries"
            ( chflags -R norestricted "$oah_stage" >/dev/null 2>&1
              rm -rf "$oah_stage" >/dev/null 2>&1 & )
        fi
    fi
fi

# CoreSymbolication cache. The whole directory goes; the OS recreates it.
if [ -d "$CSYM_DIR" ]; then
    csym_stage="${CSYM_DIR}.purging.$$"
    if mv "$CSYM_DIR" "$csym_stage" >/dev/null 2>&1; then
        echo "reclaim: staged CoreSymbolication cache"
        ( rm -rf "$csym_stage" >/dev/null 2>&1 & )
    fi
fi

# The detached deletes are still running, so this understates what will be freed.
now_gb=$(df -g / 2>/dev/null | awk 'NR==2 {print $4}')
echo "reclaim: ${avail_gb}G -> ${now_gb:-?}G free on / (detached deletes still running)"

exit 0
