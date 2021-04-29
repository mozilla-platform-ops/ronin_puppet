@echo off

rem These need to be set after the task user's profile is in place
:CheckForStuckRects3
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ /ve
if %ERRORLEVEL% EQU 0 goto netsh
ping -n 2 127.0.0.1 1>/nul
goto CheckForStuckRects3

:netsh
rem supress firewall warnings
netsh firewall set notifications mode = disable profile = all
