-- approve-screencapture.applescript
--
-- Grants Screen Recording (kTCCServiceScreenCapture) to the Taskcluster worker
-- binaries on a SIP-enabled host.
--
-- Why this exists at all: ScreenCapture is a system-scoped TCC service, so the
-- grant lives only in /Library/Application Support/com.apple.TCC/TCC.db, which
-- SIP protects. macos_tcc_perms writes that database directly on SIP-off hosts;
-- on SIP-on hosts those writes silently fail and its user-database fallback is
-- inert (TCC never reads ScreenCapture from a user database). MDM cannot close
-- the gap either: Apple only accepts AllowStandardUserToSetSystemService for
-- ScreenCapture in a PPPC payload, which authorises a standard user to approve
-- it -- it does not approve it. And there is no consent dialog to script:
--
--   tccd: Service kTCCServiceScreenCapture does not allow prompting; returning denied.
--
-- So the only remaining path is the Screen Recording pane of System Settings,
-- driven here as cltbld from a LaunchAgent so osascript has real GUI session
-- context. This mirrors macos_safaridriver's enable-remote-automation flow.
--
-- Two things make this stick rather than needing a rerun:
--   * The MDM override supplies the stored code requirement, which is anchored
--     on identifier + Developer ID team 43AQ936H96 rather than a cdhash, so a
--     worker version bump does not invalidate the grant the way the SIP-off
--     cdhash-anchored csreq does.
--   * The resulting row is auth_value 2 / auth_reason 4, identical to a working
--     SIP-off host, and survives reboot.
--
-- Requires, all supplied by the org.mozilla.ci-tcc-pppc profile plus the
-- ScreenCapture PPPC profile:
--   * Accessibility for /usr/bin/osascript (UI scripting)
--   * AllowStandardUserToSetSystemService for both worker binaries, which is
--     what makes them appear as checkboxes here and lets cltbld -- a standard
--     user -- tick them with no admin password
-- Without the ScreenCapture PPPC profile the rows simply do not appear in the
-- pane and this script errors out rather than silently reporting success.

set semaphoreFile to "/Users/cltbld/Library/Preferences/semaphore/screencapture-grant-has-run"
set semaphoreVersion to "1"
set wantedClients to {"generic-worker-multiuser", "start-worker"}
set paneURL to "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

-- Check semaphore
try
    set semaphoreContent to do shell script "cat " & quoted form of semaphoreFile
    if semaphoreContent is semaphoreVersion then
        return
    end if
on error
    -- file doesn't exist, proceed
end try

-- Create semaphore dir and empty file (signals script is running, not done)
do shell script "mkdir -p /Users/cltbld/Library/Preferences/semaphore && touch " & quoted form of semaphoreFile

-- Everything from here on must leave System Settings closed even when it fails.
-- A settings window left open on a CI worker is not cosmetic: these hosts run
-- screen-pixel tests, and a stray window changes what those tests capture.
set failure to missing value
set granted to {}

try
    -- Start from a known state: a System Settings left on some other pane by a
    -- previous run would otherwise be reused as-is.
    --
    -- The URL is opened twice with a settle delay between. One open is normally
    -- enough -- measured on macmini-m4-111 (macOS 15.3), window 1 is already
    -- named "Screen & System Audio Recording" after the first -- but the second
    -- is cheap insurance against the app being mid-launch, and re-issuing the
    -- anchor on an already-open System Settings is a no-op.
    try
        tell application "System Settings" to quit
    end try
    delay 3

    do shell script "open " & quoted form of paneURL
    delay 8
    do shell script "open " & quoted form of paneURL
    delay 8

    tell application "System Events"
        tell process "System Settings"
            set frontmost to true
            delay 3

            -- Tick each worker binary's checkbox.
            --
            -- Searched for by name rather than by locating "the outline" first:
            -- System Settings' left-hand category sidebar is ALSO an outline and
            -- a depth-first search reaches it before the client list, which is
            -- why an earlier version found an outline and then reported both
            -- clients missing.
            --
            -- Deliberately NOT `entire contents of window 1` either: on macOS
            -- 15.3 that returns an empty list here even though the pane is
            -- loaded and its elements are reachable by explicit path (observed
            -- on macmini-m4-111, window 1 correctly named "Screen & System Audio
            -- Recording" and `count of (entire contents of window 1)` = 0). A
            -- recursive descent over `UI elements` returns the real tree.
            repeat with want in wantedClients
                set cb to missing value
                -- Retry for load timing; by this point the pane itself is right.
                repeat with attempt from 1 to 6
                    set cb to my findCheckbox(window 1, want as string, 0)
                    if cb is not missing value then exit repeat
                    delay 5
                end repeat

                if cb is missing value then
                    error "client " & want & " never appeared in the Screen Recording pane -- ScreenCapture PPPC override missing for it, or the pane never finished loading"
                end if

                if value of cb is 0 then
                    click cb
                    delay 4
                end if
                if value of cb is not 1 then
                    error "could not enable Screen Recording for " & want & " (checkbox stayed off -- is AllowStandardUserToSetSystemService present for it?)"
                end if
                set end of granted to (want as string)
            end repeat
        end tell
    end tell

    if (count of granted) is not (count of wantedClients) then
        error "expected " & (count of wantedClients) & " grants, recorded " & (count of granted)
    end if
on error errMsg
    set failure to errMsg
end try

-- Close System Settings whether we succeeded or not.
try
    tell application "System Settings" to quit
end try
delay 3
try
    do shell script "/usr/bin/pkill -x 'System Settings'"
end try

if failure is not missing value then
    error failure
end if

-- Only reached when both clients are verified enabled; the error above aborts
-- first, leaving the empty semaphore written at the start so the next run retries.
do shell script "printf '1' > " & quoted form of semaphoreFile

-- Depth-first search for a checkbox with the given name. Used instead of
-- `entire contents`, which returns an empty list against this pane on
-- macOS 15.3 (see the call site). The depth cap is a guard against a
-- pathological tree, not a real limit: the client list sits ~9 levels down.
on findCheckbox(el, wantedName, depth)
    if depth > 14 then return missing value
    tell application "System Events"
        set kids to {}
        try
            set kids to UI elements of el
        on error
            return missing value
        end try
        repeat with k in kids
            try
                if class of k is checkbox and name of k is wantedName then return k
            end try
            set found to my findCheckbox(k, wantedName, depth + 1)
            if found is not missing value then return found
        end repeat
    end tell
    return missing value
end findCheckbox
