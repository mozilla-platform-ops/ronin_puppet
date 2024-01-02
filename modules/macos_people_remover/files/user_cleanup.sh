#!/bin/bash

peopleToRemove=("dhouse" "jwatkins" "mgoossens" "rthijssen")

for value in "${peopleToRemove[@]}"
do
    if test -d /Users/"$value"; then
    /usr/bin/dscl . -delete /Users/"$value" || true
    rm -rf /Users/"$value" || true
    fi
done
