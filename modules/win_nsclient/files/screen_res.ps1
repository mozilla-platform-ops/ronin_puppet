# Gets the screen resolution and prints it out on screen

$screen_res = (Get-WmiObject -Class Win32_VideoController).VideoModeDescription;

if ($screen_res -eq "1920 x 1080 x 4294967296 colors") {

    Write-Output "OK: Resolution is $screen_res"

    exit 0

} else {

    Write-Output "CRITICAL: Resolution is $screen_res"

    exit 1
