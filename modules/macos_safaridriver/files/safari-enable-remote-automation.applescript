-- safari-enable-remote-automation.applescript
-- Used on macOS 14+ (Darwin 23+) where SIP is enabled.
-- Runs via LaunchAgent as cltbld so osascript has full GUI session context.
-- Handles its own semaphore so it is idempotent.

set semaphoreFile to "/Users/cltbld/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
set semaphoreVersion to "1"

-- Check semaphore
try
    set semaphoreContent to do shell script "cat " & quoted form of semaphoreFile
    if semaphoreContent is semaphoreVersion then
        return
    end if
on error
    -- file doesn't exist, proceed
end try

-- Create semaphore dir and empty file (signals script is running)
do shell script "mkdir -p /Users/cltbld/Library/Preferences/semaphore && touch " & quoted form of semaphoreFile

-- Activate Safari
tell application "Safari"
    activate
end tell
delay 15

tell application "System Events"
    tell process "Safari"
        set frontmost to true
        delay 5

        -- Open Settings (ellipsis is U+2026)
        click menu item "Settings…" of menu "Safari" of menu bar 1
        delay 5

        -- Go to Advanced tab
        click button "Advanced" of toolbar 1 of window 1
        delay 5

        -- Enable Show features for web developers
        tell checkbox "Show features for web developers" of group 1 of group 1 of window 1
            if value is 0 then click it
            delay 5
        end tell
        delay 5

        -- Open Developer tab
        click button "Developer" of toolbar 1 of window 1
        delay 5

        -- Enable Allow remote automation
        tell checkbox "Allow remote automation" of group 1 of group 1 of window 1
            if value is 0 then click it
            delay 5
        end tell
    end tell
end tell

tell application "Safari" to quit

-- Write semaphore (version 1 = done)
do shell script "printf '1' > " & quoted form of semaphoreFile
