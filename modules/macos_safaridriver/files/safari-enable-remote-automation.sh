#!/bin/bash
set -uo pipefail

# Ensure the logged-in user is 'cltbld'
current_user=$(id -u -n)
if [ "$current_user" != "cltbld" ]; then
  echo "This script must be run as the user 'cltbld'. Current user is '$current_user'. Exiting..."
  exit 1
fi

# Track per-app failures so puppet's `unless => test -f <semaphore>` can keep retrying
# on subsequent runs until the work actually succeeds.
overall_rc=0

# Function to enable remote automation for Safari.
# Returns 0 on success (semaphore written), non-zero on failure (semaphore NOT written).
enable_remote_automation() {
  local semaphore_file="$1"
  local semaphore_version="1"
  local safari_app="$2"
  local develop_menu_text="$3"
  local allow_remote_automation_text="$4"

  if [[ -f "$semaphore_file" ]] && [[ "$(cat "$semaphore_file")" == "$semaphore_version" ]]; then
    echo "$0: $semaphore_file indicates ${safari_app} has already been configured. skipping..."
    return 0
  fi

  echo "$0: configuring ${safari_app}..."

  if ! csrutil status | grep -q 'disabled'; then
    echo "Unable to add permissions for ${safari_app}: System Integrity Protection is enabled."
    return 1
  fi

  if ! osascript -e "
    tell application \"System Events\"
      tell application \"$safari_app\" to activate
      delay 15
      tell process \"$safari_app\"
        set frontmost to true
        delay 5
        click menu item \"Settings…\" of menu 1 of menu bar item \"$safari_app\" of menu bar 1
        delay 5
        click button \"Advanced\" of toolbar 1 of window 1
        delay 5
        tell checkbox \"Show features for web developers\" of group 1 of group 1 of window 1
          if value is 0 then click it
          delay 5
        end tell
        delay 5
        click button \"$develop_menu_text\" of toolbar 1 of window 1
        delay 5
        tell checkbox \"$allow_remote_automation_text\" of group 1 of group 1 of window 1
          if value is 0 then click it
          delay 5
        end tell
      end tell
    end tell

    tell application \"$safari_app\" to quit"; then
    echo "osascript failed for ${safari_app}; semaphore not written, will retry on next puppet run."
    return 1
  fi

  # Only write the semaphore on confirmed success so puppet's `unless => test -f` retries on failure.
  mkdir -p "$(dirname "$semaphore_file")"
  echo "$semaphore_version" > "$semaphore_file"
  echo "$0: ${safari_app} configured; semaphore at $semaphore_file"
}

# Function to get the macOS version
get_macos_version() {
  sw_vers -productVersion
}

macos_full_version=$(get_macos_version)
macos_major_version=$(echo "$macos_full_version" | awk -F '.' '{print $1}')
macos_minor_version=$(echo "$macos_full_version" | awk -F '.' '{print $2}')

case "$macos_major_version" in
  "10")
    if [ "$macos_minor_version" -eq 15 ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari" "Develop" "Allow Remote Automation" || overall_rc=$?
    else
      echo "Unsupported macOS version: $macos_full_version"
      exit 1
    fi
    ;;
  "11"|"12")
    semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
    enable_remote_automation "$semaphore_file" "Safari" "Develop" "Allow Remote Automation" || overall_rc=$?
    ;;
  "13")
    semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
    enable_remote_automation "$semaphore_file" "Safari" "Developer" "Allow remote automation" || overall_rc=$?
    ;;
  "14")
    safari_version=$(/usr/libexec/PlistBuddy -c "print :CFBundleShortVersionString" /Applications/Safari.app/Contents/Info.plist)
    safari_major_version="${safari_version%%.*}"

    if [ "$safari_major_version" == "16" ] || [ "$safari_major_version" == "17" ] || [ "$safari_major_version" == "18" ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari" "Developer" "Allow remote automation" || overall_rc=$?
    fi

    if [ -d "/Applications/Safari Technology Preview.app" ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-tech-preview-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari Technology Preview" "Developer" "Allow remote automation" || overall_rc=$?
    else
      echo "Safari Technology Preview is not installed."
    fi
    ;;
  "15")
    semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
    enable_remote_automation "$semaphore_file" "Safari" "Developer" "Allow remote automation" || overall_rc=$?

    if [ -d "/Applications/Safari Technology Preview.app" ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-tech-preview-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari Technology Preview" "Developer" "Allow remote automation" || overall_rc=$?
    else
      echo "Safari Technology Preview is not installed."
    fi
    ;;
  *)
    echo "Unsupported macOS version: $macos_full_version"
    exit 1
    ;;
esac

exit "$overall_rc"
