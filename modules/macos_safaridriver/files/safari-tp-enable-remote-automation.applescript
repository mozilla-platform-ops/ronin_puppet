-- safari-tp-enable-remote-automation.applescript
-- Used on macOS 14+ (Darwin 23+) where SIP is enabled.
-- Runs via LaunchAgent as cltbld so osascript has full GUI session context.
-- Idempotent + retry-hardened.
--
-- Mirror of safari-enable-remote-automation.applescript, but addressing the
-- "Safari Technology Preview" app instead of stable Safari. Safari TP has its own
-- separate "Allow Remote Automation" toggle that the stable Safari enable does not flip.
--
-- Semaphore contract:
--   * File contains "1" ONLY on successful completion (no empty-file leftovers).
--
-- UI navigation is the PROVEN macOS 14/15 two-step (Advanced -> "Show features for
-- web developers" -> Developer tab -> "Allow remote automation"). Do NOT collapse it
-- to a one-step Advanced-pane toggle — that regressed on Safari 18.3 (ronin #1262,
-- reverted in #1279). This change only adds the retry/log/semaphore framework.

set semaphoreFile to "/Users/cltbld/Library/Preferences/semaphore/safari-tech-preview-enable-remote-automation-has-run"
set semaphoreVersion to "1"
set logFile to "/Users/cltbld/Library/Logs/safari-tp-enable-remote-automation.log"

-- Ensure log + semaphore dirs exist so error tracing works even on first run.
do shell script "mkdir -p /Users/cltbld/Library/Logs /Users/cltbld/Library/Preferences/semaphore"

on logLine(msg)
    global logFile
    do shell script "echo \"[$(date '+%Y-%m-%dT%H:%M:%S')] " & msg & "\" >> " & quoted form of logFile
end logLine

-- Skip if already succeeded (semaphore contains "1").
try
    set semaphoreContent to do shell script "cat " & quoted form of semaphoreFile
    if semaphoreContent is semaphoreVersion then
        my logLine("semaphore already at version 1 — nothing to do")
        return
    end if
on error
    -- file doesn't exist yet, proceed
end try

-- Wait for the GUI session to be ready before driving Safari TP. Dock running is the
-- standard proxy for "session initialized enough to accept UI automation".
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

-- Retry the whole UI automation up to 3 times; each attempt is idempotent.
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

                -- Open Settings (ellipsis is U+2026)
                click menu item "Settings…" of menu "Safari Technology Preview" of menu bar 1
                delay 5

                -- Go to Advanced tab
                click button "Advanced" of toolbar 1 of window 1
                delay 5

                -- Enable "Show features for web developers"
                tell checkbox "Show features for web developers" of group 1 of group 1 of window 1
                    if value is 0 then click it
                    delay 5
                    if value is not 1 then
                        error "Show features for web developers did not toggle on (value=" & (value as string) & ")"
                    end if
                end tell
                delay 5

                -- Open Developer tab
                click button "Developer" of toolbar 1 of window 1
                delay 5

                -- Enable "Allow remote automation"
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

        my logLine("remote automation enabled — writing semaphore")
        do shell script "printf '1' > " & quoted form of semaphoreFile
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
