#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 worker_type"
    echo "Worker type is ff-prod, tb-prod, or dep"
    echo "Pinned requirements will be output to stdout"
    exit 1
fi

# Note that MY_DIR is the location of the script...
pushd "$(dirname "$0")" &>/dev/null || exit
MY_DIR=$(pwd)
popd &>/dev/null || exit
# While this is the current working directory, which may
# be different
cwd=$(pwd)

trap 'cd $cwd' EXIT

worker_type=$1
common_yaml="${MY_DIR}/../../../data/common.yaml"
workdir=$(mktemp -d)

# Extract the revisions we need to find the right dependencies.
scriptworker_config="$(sed -n '/scriptworker_config/,/^$/p' "$common_yaml")"
worker_config="$(echo "$scriptworker_config" | sed -n "/${worker_type}/,/scriptworker_scripts_revision/p")"
scriptworker_revision="$(echo "$worker_config" | grep scriptworker_revision | cut -f2 -d\")"
scriptworker_scripts_revision="$(echo "$worker_config" | grep scriptworker_scripts_revision | cut -f2 -d\")"

cd "$workdir" || exit
# Our input requirements are all of the dependencies from:
# - scriptworker_client
# - iscript
# - notarization_poller
# - scriptworker
# - mozbuild
# - widevine
# Where possible we reference their requirements.in files. Where not possible, or they
# don't exist, we list them directly (which means manual updates if they change).
#
# The packages listed above are installed directly from source clones, so they do not need
# to go in the requirements file.
cat <<EOF > requirements.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/$scriptworker_scripts_revision/scriptworker_client/requirements/base.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/$scriptworker_scripts_revision/iscript/requirements/base.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/$scriptworker_scripts_revision/notarization_poller/requirements/base.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker/$scriptworker_revision/requirements.txt

# mozbuild dependencies
jsmin>=3
mozfile

# widevine dependencies
cryptography
macholib
EOF

# Generated pinned requirements
pip-compile --allow-unsafe --generate-hashes -r requirements.in 2>&1
