-- safari-enable-remote-automation.applescript
-- Used on macOS 14+ (Darwin 23+) where SIP is enabled.
-- Runs via LaunchAgent as cltbld so osascript has full GUI session context.
-- Idempotent + retry-hardened.
--
-- Semaphore contract:
--   * File contains "1" only on successful completion.
--   * File does NOT exist between runs — no empty-file leftovers to confuse
--     downstream checks (puppet exec `unless`, driver LaunchDaemon
--     check_done, etc.). If this script fails, the file is not written at
--     all, and the next invocation starts fresh.

set semaphoreFile to "/Users/cltbld/Library/Preferences/semaphore/safari-enable-remote-automation-has-run"
set semaphoreVersion to "1"
set logFile to "/Users/cltbld/Library/Logs/safari-enable-remote-automation.log"

-- Ensure log dir + semaphore dir exist so error tracing works even on first run
do shell script "mkdir -p /Users/cltbld/Library/Logs /Users/cltbld/Library/Preferences/semaphore"

on logLine(msg)
    global logFile
    do shell script "echo \"[$(date '+%Y-%m-%dT%H:%M:%S')] " & msg & "\" >> " & quoted form of logFile
end logLine

-- Skip if already succeeded (semaphore contains "1")
try
    set semaphoreContent to do shell script "cat " & quoted form of semaphoreFile
    if semaphoreContent is semaphoreVersion then
        my logLine("semaphore already at version 1 — nothing to do")
        return
    end if
on error
    -- file doesn't exist yet, proceed
end try

-- Wait for GUI session to be fully ready before driving Safari.
-- Dock running is the standard proxy for "user session initialized enough
-- to accept UI automation". The LaunchAgent can fire before this on a
-- fresh login, so we wait up to 60s.
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

-- Additional settle time — even after Dock is running, Safari's initial
-- launch can hit races with the menu-bar accessibility tree if we jump
-- straight in.
delay 5

-- Retry the whole UI automation up to 3 times. Each attempt is idempotent
-- (each click checks state before toggling), so a partial success doesn't
-- corrupt anything on the next attempt.
set maxAttempts to 3
set attempt to 0
repeat maxAttempts times
    set attempt to attempt + 1
    my logLine("attempt " & attempt & " of " & maxAttempts)
    try
        -- Activate Safari (also launches it if not running)
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

                -- Enable "Allow remote automation"
                -- Safari 18 (macOS 15) restructured the Settings UI: the Advanced
                -- pane now contains what used to be a separate Developer tab,
                -- and the "Show features for web developers" gate was removed
                -- entirely. "Allow remote automation" is directly at the same
                -- depth. If we ever need to support older Safari (17 / macOS 14),
                -- we'd need to conditionalize this or fall back to the old
                -- two-step (enable dev features -> Developer tab -> click).
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

        -- Success. Write semaphore only now that both toggles are verified.
        do shell script "printf '1' > " & quoted form of semaphoreFile
        my logLine("attempt " & attempt & " succeeded, semaphore written")
        return

    on error errMsg number errNum
        my logLine("attempt " & attempt & " failed (error " & errNum & "): " & errMsg)
        -- Clean up any partial Safari state before the next attempt
        try
            tell application "Safari" to quit
        end try
        delay 10
    end try
end repeat

my logLine("all " & maxAttempts & " attempts failed")
error "safari enable script failed after " & maxAttempts & " attempts — see " & logFile
