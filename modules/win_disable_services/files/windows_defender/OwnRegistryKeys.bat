@echo off

rem Get the location of the PowerShell file.
for /f "usebackq tokens=*" %%f in (`where "OwnRegistryKeys.ps1"`) do (
    rem Run command for each argument.
    for %%a in (%*) do (
        powershell -executionPolicy bypass -file "%%~f" "%%~a"
    )
)
