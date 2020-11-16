:CheckForStuckRects3
echo Wait for registry setting to exist before changing it...
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3 /ve
if %ERRORLEVEL% EQU 0 goto HideTaskBar
echo HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3 does not yet exist
ping -n 2 127.0.0.1 1>/nul
goto CheckForStuckRects3

rem supress firewall warnings
netsh firewall set notifications mode = disable profile = all
