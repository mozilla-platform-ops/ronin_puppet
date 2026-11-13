#!/bin/bash
#
# Install a root-staged LaunchAgent plist into a user's ~/Library/LaunchAgents,
# running as that user.
#
# Puppet previously managed these plists with a `file` resource pointing
# straight at /Users/cltbld/Library/LaunchAgents/... as root with
# owner => cltbld. Puppet replaces a symlink at the terminal path, but it does
# not detect symlinked ANCESTOR directories -- the kernel resolves those
# transparently -- and every component under /Users/cltbld is owned and
# writable by cltbld, the account untrusted CI task payloads run as. So a task
# could do:
#
#   rm -rf ~/Library/LaunchAgents && ln -s /etc/periodic/daily ~/Library/LaunchAgents
#
# and the next converge would have root create a cltbld-owned file in
# /etc/periodic/daily. cltbld then rewrites its contents (it owns the file) and
# periodic(8) executes it as root. No race: puppet re-converges on a schedule
# and the symlink can be re-pointed between runs.
#
# Doing the install as the target user removes root from the path entirely.
# The plist has to be user-owned anyway for `launchctl bootstrap gui/<uid>`,
# so nothing is lost. If the user has redirected the path at something it
# cannot write, install(1) fails as that user and this script exits non-zero,
# turning the tampering into a red puppet run rather than a root compromise.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <user> <staged-plist>" >&2
  exit 2
fi

user="$1"
src="$2"

if [ ! -f "$src" ]; then
  echo "$0: staged plist ${src} not found" >&2
  exit 1
fi

home="$(/usr/bin/dscl . -read "/Users/${user}" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
if [ -z "$home" ]; then
  echo "$0: could not resolve home directory for ${user}" >&2
  exit 1
fi

dst_dir="${home}/Library/LaunchAgents"
dst="${dst_dir}/$(/usr/bin/basename "$src")"

/usr/bin/sudo -u "$user" /usr/bin/install -d -m 0755 "$dst_dir"
/usr/bin/sudo -u "$user" /usr/bin/install -m 0644 "$src" "$dst"
