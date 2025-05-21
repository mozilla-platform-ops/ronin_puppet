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

## postinst script

The postinst script sets up the google repository. After a `apt update`, you should
be able to `apt install google-chrome-stable`.

### Changes made

1. line 2. `# shellcheck disable=all`
2.

## install_repo script

Repackaged version just for our use.

Takes the functions we want and uses our own main.

## install_repo_automated script

Similar to `install_repo` script, but made in an automated manner.

```
# extract the ast
./extract.sh

# generate install_repo_automated
./process.py

```
