If ((Test-Path Z:\)) {
    write-host "custom_win_z_drive=exists"
}

If ((Test-Path D:\)) {
    write-host "custom_win_d_drive=exists"
}
