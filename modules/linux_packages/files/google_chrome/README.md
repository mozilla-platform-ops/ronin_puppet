# google chrome installation files

## overview

Extracted from a Google Chrome deb.

### Questions

#### Why do this?

Saves us from having to rewrite these steps. If these break, just pull the deb again and update.

#### Why not just use the full deb?

It's 115MB. It's nice to avoid storing it.

## extraction process

```
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg-deb -e google-chrome-stable_current_amd64.deb google-chrome-stable_current_amd64_control
# postinst is the interesting one for us
```

## `install_repo` script

Repackaged version just for our use.

Takes the functions we want and uses our own main.

### Changes made

1. line 2. `# shellcheck disable=all`
2. crafted new main by analyzing needed functions
3. added in required functions and variables until it worked (debugged with set -x)

## `install_repo_automated` script

Similar to `install_repo` script, but made in an automated manner.

`extract.sh` converts the `postinst` script to an AST (https://en.wikipedia.org/wiki/Abstract_syntax_tree) so that we can later select the parts of the script we'd like (declarations and functions, but not function invocations basically). `process.py` does the selection of the AST parts and outputs of the new script based on an inline template.

```
# extract the ast
./extract.sh

# generate install_repo_automated
./process.py

# see `install_repo_automated`
```
