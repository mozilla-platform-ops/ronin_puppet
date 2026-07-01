-- safari-tp-enable-remote-automation.applescript
-- Used on macOS 14+ (Darwin 23+) where SIP is enabled.
-- Runs via LaunchAgent as cltbld so osascript has full GUI session context.
-- Idempotent + retry-hardened.
--
-- Mirror of safari-enable-remote-automation.applescript, but addressing the
-- "Safari Technology Preview" app instead of stable Safari. Safari TP has
-- its own separate "Allow Remote Automation" toggle that the stable Safari
-- enable does not flip.
--
-- Semaphore contract: same as the stable Safari script — file contains "1"
-- only on success, does NOT exist between runs.

set semaphoreFile to "/Users/cltbld/Library/Preferences/semaphore/safari-tech-preview-enable-remote-automation-has-run"
set semaphoreVersion to "1"
set logFile to "/Users/cltbld/Library/Logs/safari-tp-enable-remote-automation.log"

do shell script "mkdir -p /Users/cltbld/Library/Logs /Users/cltbld/Library/Preferences/semaphore"

on logLine(msg)
    global logFile
    do shell script "echo \"[$(date '+%Y-%m-%dT%H:%M:%S')] " & msg & "\" >> " & quoted form of logFile
end logLine

-- Skip if already succeeded
try
    set semaphoreContent to do shell script "cat " & quoted form of semaphoreFile
    if semaphoreContent is semaphoreVersion then
        my logLine("semaphore already at version 1 — nothing to do")
        return
    end if
on error
    -- file doesn't exist yet
end try

my logLine("waiting for Dock to be running (GUI session readiness)")
set dockReady to false
repeat 12 times
    try
        do shell script "pgrep -x Dock >/dev/null"
        set dockReady to true
        exit repeat
    on error
        delay 5
    end try
end repeat
if not dockReady then
    my logLine("Dock never came up — bailing")
    error "GUI session did not initialize (Dock process absent after 60s)"
end if
my logLine("Dock is up")

delay 5

set maxAttempts to 3
set attempt to 0
repeat maxAttempts times
    set attempt to attempt + 1
    my logLine("attempt " & attempt & " of " & maxAttempts)
    try
        tell application "Safari Technology Preview"
            activate
        end tell
        delay 15

        tell application "System Events"
            tell process "Safari Technology Preview"
                set frontmost to true
                delay 5

                click menu item "Settings…" of menu "Safari Technology Preview" of menu bar 1
                delay 5

                click button "Advanced" of toolbar 1 of window 1
                delay 5

                -- Safari 18 consolidation (see stable-Safari script for details) —
                -- "Allow remote automation" is directly in the Advanced pane.
                tell checkbox "Allow remote automation" of group 1 of group 1 of window 1
                    if value is 0 then click it
                    delay 5
                    if value is not 1 then
                        error "Allow remote automation did not toggle on (value=" & (value as string) & ")"
                    end if
                end tell
            end tell
        end tell

        tell application "Safari Technology Preview" to quit

        do shell script "printf '1' > " & quoted form of semaphoreFile
        my logLine("attempt " & attempt & " succeeded, semaphore written")
        return

    on error errMsg number errNum
        my logLine("attempt " & attempt & " failed (error " & errNum & "): " & errMsg)
        try
            tell application "Safari Technology Preview" to quit
        end try
        delay 10
    end try
end repeat

my logLine("all " & maxAttempts & " attempts failed")
error "safari TP enable script failed after " & maxAttempts & " attempts — see " & logFile
