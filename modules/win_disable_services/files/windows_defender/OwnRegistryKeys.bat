@echo off

rem Run command for each argument.
for %%a in (%*) do (
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -executionPolicy bypass -file "%~dp0OwnRegistryKeys.ps1" "%%~a"
)
