class win_os_settings::hide_start_menu {

    registry::value { 'Start_ShowClassicMode' :
        key  => 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
        type => dword,
        data => '0',
    }
}
