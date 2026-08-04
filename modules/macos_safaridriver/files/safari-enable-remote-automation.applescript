-- safari-enable-remote-automation.applescript
-- Used on macOS 14+ (Darwin 23+) where SIP is enabled.
-- Runs via LaunchAgent as cltbld so osascript has full GUI session context.
-- Idempotent + retry-hardened.
--
-- Semaphore contract:
--   * File contains "1" ONLY on successful completion.
--   * File does NOT exist between runs — no empty-file leftovers to confuse the
--     downstream checks (puppet exec `unless`, the driver check_done, the exec's
--     polling loop). If this script fails, the file is not written at all, and the
--     next invocation starts fresh.
--
-- UI navigation is the PROVEN macOS 14/15 two-step: Advanced pane ->
-- "Show features for web developers" -> Developer tab -> "Allow remote automation".
-- Do NOT "simplify" this to a one-step direct toggle in the Advanced pane: the
-- "Allow remote automation" checkbox is NOT in the Advanced pane on macOS 15.3 /
-- Safari 18.3 (System Events -1728 "can't get checkbox"). That regression was
-- ronin #1262, reverted in #1279. This change only adds the retry/log/semaphore
-- framework around the same proven UI steps.

set semaphoreFile to "/Users/cltbld/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
set semaphoreVersion to "1"
set logFile to "/Users/cltbld/Library/Logs/safari-enable-remote-automation.log"

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

-- Wait for the GUI session to be ready before driving Safari. Dock running is the
-- standard proxy for "session initialized enough to accept UI automation" — the
-- LaunchAgent can fire before this on a fresh cltbld autologin.
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

-- Extra settle time even after Dock — Safari's first launch can race the menu-bar
-- accessibility tree if we jump straight in.
delay 5

-- Retry the whole UI automation up to 3 times. Each attempt is idempotent (each
-- toggle checks state before clicking), so a partial success doesn't corrupt
-- anything on the next attempt.
set maxAttempts to 3
set attempt to 0
repeat maxAttempts times
    set attempt to attempt + 1
    my logLine("attempt " & attempt & " of " & maxAttempts)
    try
        -- Activate Safari (also launches it if not running).
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

        tell application "Safari" to quit

        -- Success — write the semaphore and stop.
        my logLine("remote automation enabled — writing semaphore")
        do shell script "printf '1' > " & quoted form of semaphoreFile
        return
    on error errMsg number errNum
        my logLine("attempt " & attempt & " failed (error " & errNum & "): " & errMsg)
        try
            tell application "Safari" to quit
        end try
        delay 10
    end try
end repeat

my logLine("all " & maxAttempts & " attempts failed")
error "safari enable script failed after " & maxAttempts & " attempts — see " & logFile
