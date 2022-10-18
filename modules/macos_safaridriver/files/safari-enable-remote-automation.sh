#!/usr/bin/env bash

set -e

# based on https://circleci.com/developer/orbs/orb/circleci/macos#commands-add-safari-permissions

if [ "$EUID" -eq 0 ]; then
  echo "Must not run as root!"
  echo "  'Allow Remote Automation' is per account."
  exit 1
fi

current_user=$(id -u -n)
semaphore_file="/Users/$current_user/Library/Preferences/semaphare/safari-enable-remote-automation-has-run"
semaphore_version="1"
mkdir -p "$(dirname "$semaphore_file")"
touch "$semaphore_file"
if [[ "$(cat "$semaphore_file")" == "$semaphore_version" ]]; then
  echo "$0: file indicates this version of the script has already run. exiting..."
  exit 0
else
  echo "$0: running..."
fi

if csrutil status | grep -q 'disabled'; then
    # TCC DB changes moved elsewhere

    # issue: code below will disable/enable 'allow remote automation'
    #   - no way to 'enable' only 'click'
    #      see '(click menu item "Allow Remote Automation")' below
    #   - current solution: semaphore above
    osascript -e '
      tell application "System Events"
        tell application "Safari" to activate
        delay 15
        tell process "Safari"
          set frontmost to true
          delay 5
          click menu item "Preferences…" of menu 1 of menu bar item "Safari" of menu bar 1
          delay 5
          click button "Advanced" of toolbar 1 of window 1
          delay 5
          tell checkbox "Show Develop menu in menu bar" of group 1 of group 1 of window 1
            if value is 0 then click it
            delay 5
          end tell
          click button 1 of window 1
          delay 5
          click menu item "Allow Remote Automation" of menu 1 of menu bar item "Develop" of menu bar 1
          delay 5
        end tell
      end tell'

    # `sudo safaridriver --enable` enable done somewhere else
else
    echo "Unable to add permissions! System Integrity Protection is enabled."
    exit 1
fi

echo "$semaphore_version" > "$semaphore_file"
