class win_os_settings::hide_start_menu {

    registry::value { 'HideRecommendedSection' :
        key  => 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer',
        type => dword,
        data => '1',
    }
}
