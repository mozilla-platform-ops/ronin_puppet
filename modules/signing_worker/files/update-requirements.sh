#!/usr/bin/env bash

# This script will create a docker image on the local machine with name "pip-compile"
# It is safe to delete such image after running this script
# It will also fetch yq and python images which can be safely removed from the local image cache

# Configuration
yq_docker_image=mikefarah/yq:4.28.2
python_docker_image=python:3.8.3-alpine3.12

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
common_yaml=$(readlink -f "${MY_DIR}/../../../data/common.yaml")
workdir=$(mktemp -d)

# pull docker images
docker pull "${yq_docker_image}" &>/dev/null || exit
docker pull "${python_docker_image}" &>/dev/null || exit

# build python pip-tools for pip-compile
dockerfile="FROM ${python_docker_image}
RUN pip install pip-tools"
echo "${dockerfile}" | docker build -q -t pip-compile - &>/dev/null || exit

# Extract the revisions we need to find the right dependencies.
scriptworker_revision=$(docker run --rm -it -v "${common_yaml}:/workdir/common.yaml" ${yq_docker_image} ".scriptworker_config.${worker_type}.scriptworker_revision" common.yaml | tr -d '\r')
scriptworker_scripts_revision=$(docker run --rm -it -v "${common_yaml}:/workdir/common.yaml" ${yq_docker_image} ".scriptworker_config.${worker_type}.scriptworker_scripts_revision" common.yaml | tr -d '\r')

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
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/${scriptworker_scripts_revision}/scriptworker_client/requirements/base.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/${scriptworker_scripts_revision}/iscript/requirements/base.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker-scripts/${scriptworker_scripts_revision}/notarization_poller/requirements/base.in
-r https://raw.githubusercontent.com/mozilla-releng/scriptworker/${scriptworker_revision}/requirements.txt

# mozbuild dependencies
jsmin>=3
mozfile

# widevine dependencies
cryptography
macholib
EOF


# run pip-compile
docker run --rm -v "$(readlink -f ./requirements.in):/w/requirements.in" -w /w pip-compile pip-compile --generate-hashes -r requirements.in 2>&1