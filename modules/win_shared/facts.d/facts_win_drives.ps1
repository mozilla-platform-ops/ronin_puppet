If ((Test-Path Z:\)) {
    write-host "custom_win_z_drive=exists"
}

If ((Test-Path Y:\)) {
    write-host "custom_win_y_drive=exists"
}

If ((Test-Path D:\)) {
    write-host "custom_win_d_drive=exists"
}
