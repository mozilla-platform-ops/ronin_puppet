:: Task User initialisation script - this script runs as task user, not as administrator.
:: It runs after task user has logged in, but before worker claims a task.

@echo off

:CheckForStuckRects3
echo Wait for registry setting to exist before changing it...
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3 /ve
if %ERRORLEVEL% EQU 0 goto HideTaskBar
:: Commenting out echo below to reduce logging
:: echo HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3 does not yet exist
:: Cannot use timeout command from non-interactive process
:: (try it yourself with e.g. `echo hello | timeout /t 1`)
ping -n 2 127.0.0.1 1>/nul
goto CheckForStuckRects3

:HideTaskBar
echo Hiding taskbar...
powershell -command "&{$p='HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3';$v=(Get-ItemProperty -Path $p).Settings;$v[8]=3;&Set-ItemProperty -Path $p -Name Settings -Value $v;&Stop-Process -ProcessName explorer}"

echo Setting visual effects
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t REG_DWORD /d 1 /f

:: Holding off including this here for now, as we will likely be doing this in preflight
:: scripts in future. See: https://bugzilla.mozilla.org/show_bug.cgi?id=1396168#c13
::
:: :: Task user firewall exceptions
:: netsh advfirewall firewall add rule name="ssltunnel-%USERNAME%" dir=in action=allow program="%USERPROFILE%\build\tests\bin\ssltunnel.exe" enable=yes
:: netsh advfirewall firewall add rule name="ssltunnel-%USERNAME%" dir=out action=allow program="%USERPROFILE%\build\tests\bin\ssltunnel.exe" enable=yes
:: netsh advfirewall firewall add rule name="python-%USERNAME%" dir=in action=allow program="%USERPROFILE%\build\venv\scripts\python.exe" enable=yes
:: netsh advfirewall firewall add rule name="python-%USERNAME%" dir=out action=allow program="%USERPROFILE%\build\venv\scripts\python.exe" enable=yes

echo Completed task user initialisation.
