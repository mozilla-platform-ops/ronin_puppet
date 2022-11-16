#!/usr/bin/env bash

set -e
# set -x

# TODO: check that this is run as root

# remove previous versions of these as they mess with installation
# TODO: check exit code? 100 is ok - means not present...
apt remove libpython3.9-minimal libpython3.9-stdlib -y || true

# order matters
#   created with https://github.com/starkandwayne/install-debs-in-order
dpkg -i libpython3.9-minimal_3.9.15-1+bionic1_amd64.deb
dpkg -i python3.9-lib2to3_3.9.15-1+bionic1_all.deb
dpkg -i libpython3.9-stdlib_3.9.15-1+bionic1_amd64.deb
dpkg -i python3.9-distutils_3.9.15-1+bionic1_all.deb
dpkg -i python3.9-minimal_3.9.15-1+bionic1_amd64.deb
dpkg -i libpython3.9_3.9.15-1+bionic1_amd64.deb
dpkg -i python3.9_3.9.15-1+bionic1_amd64.deb
dpkg -i libpython3.9-dev_3.9.15-1+bionic1_amd64.deb
dpkg -i python3.9-venv_3.9.15-1+bionic1_amd64.deb
dpkg -i python3.9-dev_3.9.15-1+bionic1_amd64.deb

# changing /usr/bin/python3 makes various things unhappy due to dynamic lib naming
# - `apt update`
# - gnome-terminal (used to launch worker-runner)
#
# takeaways: we shouldn't change the python version (/usr/bin/python3 from 3.6 to 3.9)
#   the system uses in the future.
#
# Traceback (most recent call last):
#   File "/usr/lib/cnf-update-db", line 8, in <module>
#     from CommandNotFound.db.creator import DbCreator
#   File "/usr/lib/python3/dist-packages/CommandNotFound/db/creator.py", line 11, in <module>
#     import apt_pkg
# ModuleNotFoundError: No module named 'apt_pkg'
#
cd /usr/lib/python3/dist-packages
ln -s apt_pkg.cpython-36m-x86_64-linux-gnu.so apt_pkg.so
cd -

cd /usr/lib/python3/dist-packages/gi
ln -s _gi.cpython-36m-x86_64-linux-gnu.so _gi.so
cd -

apt install --fix-broken -y
