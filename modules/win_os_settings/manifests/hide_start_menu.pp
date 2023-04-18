class win_os_settings::hide_start_menu {

    $explorer_key ="HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer"
    $start_pg_key ="${explorer_key}\\StartPage"

    registry::value { 'HideRecommendedSect':
        key  => $explorer_key,
        type => dword,
        data => '1',
    }
    registry::value { 'DisableSearchBoxSuggestions':
        key  => $explorer_key,
        type => dword,
        data => '1',
    }
    registry::value { 'Start_ShowClassicMode':
        key  => $explorer_key,
        type => dword,
        data => '1',
    }
}
