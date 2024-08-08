#!/bin/bash

# Function to enable remote automation for Safari
enable_remote_automation() {
  local semaphore_file="$1"
  local semaphore_version="1"
  local safari_app="$2"
  local develop_menu_text="$3"
  local allow_remote_automation_text="$4"

  current_user=$(id -u -n)
  mkdir -p "$(dirname "$semaphore_file")"
  touch "$semaphore_file"

  if [[ "$(cat "$semaphore_file")" == "$semaphore_version" ]]; then
    echo "$0: file indicates this version of the script has already run. exiting..."
    exit 0
  else
    echo "$0: running..."
  fi

  if csrutil status | grep -q 'disabled'; then
    osascript -e "
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

      tell application \"$safari_app\" to quit"
  else
    echo "Unable to add permissions! System Integrity Protection is enabled."
    exit 1
  fi

  echo "$semaphore_version" > "$semaphore_file"
}

# Function to get the macOS version
get_macos_version() {
  sw_vers -productVersion
}

macos_full_version=$(get_macos_version)
macos_major_version=$(echo "$macos_full_version" | awk -F '.' '{print $1}')
macos_minor_version=$(echo "$macos_full_version" | awk -F '.' '{print $2}')

# Ensure not running as root
if [ "$EUID" -eq 0 ]; then
  echo "Must not run as root!"
  echo "  'Allow Remote Automation' is per account."
  exit 1
fi

current_user=$(id -u -n)

case "$macos_major_version" in
  "10")
    if [ "$macos_minor_version" -eq 15 ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari" "Develop" "Allow Remote Automation"
    else
      echo "Unsupported macOS version: $macos_full_version"
      exit 1
    fi
    ;;
  "11"|"12")
    semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
    enable_remote_automation "$semaphore_file" "Safari" "Develop" "Allow Remote Automation"
    ;;
  "13")
    semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
    enable_remote_automation "$semaphore_file" "Safari" "Developer" "Allow remote automation"
    ;;
  "14")
    # Get current version of Safari.app
    safari_version=$(/usr/libexec/PlistBuddy -c "print :CFBundleShortVersionString" /Applications/Safari.app/Contents/Info.plist)
    safari_major_version="${safari_version%%.*}"

    if [ "$safari_major_version" == "16" ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari" "Developer" "Allow remote automation"
    elif [ "$safari_major_version" == "17" ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari" "Developer" "Allow remote automation"
    fi

    # Check for Safari Technology Preview
    if [ -d "/Applications/Safari Technology Preview.app" ]; then
      semaphore_file="/Users/$current_user/Library/Preferences/semaphore/safari-tech-preview-enable-remote-automation-has-run"
      enable_remote_automation "$semaphore_file" "Safari Technology Preview" "Developer" "Allow remote automation"
    else
      echo "Safari Technology Preview is not installed."
    fi
    ;;
  *)
    echo "Unsupported macOS version: $macos_full_version"
    exit 1
    ;;
esac
