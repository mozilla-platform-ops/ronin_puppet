#!/usr/bin/env bash

set -e
# set -x

# check that shfmt is installed
if ! command -v shfmt &> /dev/null
then
    echo "shfmt could not be found"
    echo "  on os x, you can install it with brew install shfmt"
    exit
fi

# convert script to ast
#
# cat postinst | shfmt -tojson > ast.json
# fancier version of above
shfmt -tojson < postinst > ast.json
echo "done"
