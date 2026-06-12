#!/bin/bash

peopleToRemove=("dhouse" "jwatkins" "mgoossens" "rthijssen" "andrej" "michelle")

# --check: report whether there is anything to do, without changing state.
# Exit 1 if any listed user still has a home directory (work to do), else 0.
# Puppet uses this as the exec's `unless`, so the user list lives only here.
if [[ "$1" == "--check" ]]; then
    for value in "${peopleToRemove[@]}"; do
        test -d /Users/"$value" && exit 1
    done
    exit 0
fi

for value in "${peopleToRemove[@]}"
do
    if test -d /Users/"$value"; then
    /usr/bin/dscl . -delete /Users/"$value" || true
    rm -rf /Users/"$value" || true
    fi
done
