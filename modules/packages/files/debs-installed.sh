#!/bin/sh
# Succeed only when every verified archive's exact version is installed.
set -eu

[ "$#" -gt 0 ] || exit 1
for archive do
    package=$(/usr/bin/dpkg-deb --field "$archive" Package) || exit 1
    version=$(/usr/bin/dpkg-deb --field "$archive" Version) || exit 1
    architecture=$(/usr/bin/dpkg-deb --field "$archive" Architecture) || exit 1
    if [ "$architecture" = all ]; then
        query=$package
    else
        query=$package:$architecture
    fi
    installed=$(/usr/bin/dpkg-query --show --showformat='${Status}\t${Version}' "$query") || exit 1
    expected=$(printf 'install ok installed\t%s' "$version")
    [ "$installed" = "$expected" ] || exit 1
done
