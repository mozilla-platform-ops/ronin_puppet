#!/usr/bin/env bash

# This script will create a docker image on the local machine with name "pip-compile"
# It is safe to delete such image after running this script
# It will also fetch yq and python images which can be safely removed from the local image cache

# Configuration
yq_docker_image=mikefarah/yq:4.28.2@sha256:473c4bc63c7b36793b4dbc980e183026d5422cb1ec6fe1f1cc12f1bc1b2e8be9
python_docker_image=python:3.8.3-alpine3.12@sha256:6c1b18373c4f94353308097772e97ff4d0e596ac3d06cc4b00c3bdc52cd5e8b6

# Note that MY_DIR is the location of the script...
pushd "$(dirname "$0")" &>/dev/null || exit
MY_DIR=$(pwd)
popd &>/dev/null || exit
# While this is the current working directory, which may
# be different
cwd=$(pwd)

cli_param=$1

if [ -z "$cli_param" ]; then
    worker_types=()
    echo "Updating all requirement files"
    for f in ${MY_DIR}/requirements.*; do
        target=$(echo $f | awk -F '.' '{print $2}')
        echo "Found target: ${target}"
        worker_types+=("${target}")
    done
else
    worker_types=($cli_param)
    echo "Updating single env: ${cli_param}"
fi

# build Dockerfile with python pip-tools for pip-compile
dockerfile="FROM ${python_docker_image}
RUN --mount=type=cache,target=/root/.cache pip install pip-tools"
echo "${dockerfile}" | docker build -q -t pip-compile - || exit


# Set working directory back to current dir on exit
trap 'cd $cwd' EXIT

# Temp working directory
workdir=$(mktemp -d)
cd "$workdir" || exit

compile() {
    worker_type=$1

    common_yaml=$(readlink -f "${MY_DIR}/../../../data/common.yaml")
    # Extract the revisions we need to find the right dependencies.
    scriptworker_revision=$(docker run --rm -it -v "${common_yaml}:/workdir/common.yaml" ${yq_docker_image} ".scriptworker_config.${worker_type}.scriptworker_revision" common.yaml | tr -d '\r')
    scriptworker_scripts_revision=$(docker run --rm -it -v "${common_yaml}:/workdir/common.yaml" ${yq_docker_image} ".scriptworker_config.${worker_type}.scriptworker_scripts_revision" common.yaml | tr -d '\r')
    if [ -z "$scriptworker_revision" ] || [ -z "$scriptworker_scripts_revision" ]; then
        echo "Unable to find revisions for ${worker_type}:"
        echo "  scriptworker_revision:         $scriptworker_revision"
        echo "  scriptworker_scripts_revision: $scriptworker_scripts_revision"
        exit 1
    fi

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

    output_file="requirements.${worker_type}.txt"

    # run pip-compile
    docker run \
        --rm \
        -v "$workdir:/workdir" \
        -w "/workdir" \
        pip-compile:latest \
        pip-compile -q --generate-hashes -o $output_file -r requirements.in
    
    cp "${workdir}/${output_file}" "${MY_DIR}/${output_file}"
    rm "${output_file}" "requirements.in"
}

for wt in "${worker_types[@]}"; do
    echo "Compiling $wt"
    compile $wt
    echo "Done compiling $wt"
    echo "##################"
done
