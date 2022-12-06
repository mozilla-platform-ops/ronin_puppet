:: Task User initialisation script - this script runs as task user, not as administrator.
:: It runs after task user has logged in, but before worker claims a task.

:WaitForExplorerKey
echo Wait for Explorer registry key to exist before allowing a task to run...
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer /ve
if %ERRORLEVEL% EQU 0 goto Completed
echo HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer does not yet exist
:: Cannot use timeout command from non-interactive process
:: (try it yourself with e.g. `echo hello | timeout /t 1`)
ping -n 2 127.0.0.1 1>/nul
goto WaitForExplorerKey

:Completed
echo Completed task user initialisation.
