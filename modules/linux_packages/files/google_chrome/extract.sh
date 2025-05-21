#!/usr/bin/env bash

set -e
set -x

# convert script to ast
# cat postinst | shfmt -tojson > ast.json

shfmt -tojson < postinst > ast.json
